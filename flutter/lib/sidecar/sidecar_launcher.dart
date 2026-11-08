import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'paths.dart';

enum SidecarState { stopped, starting, ready, failed }

class SidecarLauncher {
  SidecarLauncher(this.paths);

  final EaselPaths paths;
  Process? _process;
  int? port;
  SidecarState state = SidecarState.stopped;
  String? lastError;
  final _log = StringBuffer();

  String get baseUrl => 'http://127.0.0.1:$port';
  String get logText => _log.toString();

  Future<void> start() async {
    if (state == SidecarState.ready || state == SidecarState.starting) return;
    state = SidecarState.starting;
    lastError = null;
    _log.clear();

    final python = paths.pythonExe;
    final app = paths.webApp;
    if (!python.existsSync()) {
      state = SidecarState.failed;
      lastError = 'Vendor Python missing: ${python.path}';
      return;
    }
    if (!app.existsSync()) {
      state = SidecarState.failed;
      lastError = 'web/app.py missing: ${app.path}';
      return;
    }

    port = await _pickFreePort();
    final env = Map<String, String>.from(Platform.environment);
    env['EASEL_ROOT'] = paths.easelRoot.path;
    env['EASEL_MODELS_DIR'] = paths.modelsDir.path;
    env['EASEL_OPENCLAW_STATE_DIR'] = paths.openclawStateDir.path;
    env['EASEL_DATA_DIR'] = paths.dataDir.path;
    env['EASEL_PORT'] = '$port';
    env['EASEL_CHAT_TRANSPORT'] = env['EASEL_CHAT_TRANSPORT'] ?? 'http';
    // OpenClaw macOS SQLite staging uses $XDG_CACHE_HOME/openclaw (else
    // ~/Library/Caches, often EPERM under Flutter). Keep both cache + tmp
    // inside the app sandbox.
    final tmpDir = Directory(p.join(paths.dataDir.path, 'tmp'));
    final cacheDir = Directory(p.join(paths.dataDir.path, 'cache'));
    final openclawCache = Directory(p.join(cacheDir.path, 'openclaw'));
    for (final d in [tmpDir, cacheDir, openclawCache]) {
      if (!d.existsSync()) d.createSync(recursive: true);
    }
    env['EASEL_TMPDIR'] = tmpDir.path;
    env['EASEL_CACHE_DIR'] = cacheDir.path;
    env['XDG_CACHE_HOME'] = cacheDir.path;
    env['TMPDIR'] = tmpDir.path;
    env['TMP'] = tmpDir.path;
    env['TEMP'] = tmpDir.path;
    if (paths.devRepoMode) {
      env.remove('EASEL_PACKAGED');
      // Keep any developer-set vendor; otherwise leave unset for PATH discovery.
    } else {
      env['EASEL_VENDOR_ROOT'] = paths.vendorRoot.path;
      env['EASEL_PACKAGED'] = '1';
    }

    // Skill scripts use `#!/usr/bin/env python3` — pin vendor interpreter + PATH.
    if (python.existsSync() && python.path.contains(Platform.pathSeparator)) {
      env['EASEL_PYTHON'] = python.path;
    }

    final pathKey = Platform.isWindows ? 'Path' : 'PATH';
    final sep = Platform.isWindows ? ';' : ':';
    final prefixes = <String>[
      p.join(paths.vendorRoot.path, 'ffmpeg', 'bin'),
      p.join(paths.vendorRoot.path, 'node', 'bin'),
      p.join(paths.vendorRoot.path, 'node'),
      p.join(paths.vendorRoot.path, 'openclaw', 'node_modules', '.bin'),
      p.join(paths.vendorRoot.path, 'python', 'bin'),
      p.join(paths.vendorRoot.path, 'python', 'Scripts'),
    ].where((d) => Directory(d).existsSync()).toList();
    if (prefixes.isNotEmpty) {
      env[pathKey] = [...prefixes, env[pathKey] ?? ''].join(sep);
    }

    _log.writeln('Starting sidecar on :$port');
    _log.writeln('python=${python.path}');
    _log.writeln('EASEL_PYTHON=${env['EASEL_PYTHON'] ?? ''}');
    _log.writeln('vendor=${paths.vendorRoot.path}');
    _log.writeln('easelRoot=${paths.easelRoot.path}');
    _log.writeln('devRepoMode=${paths.devRepoMode}');

    final pythonCmd = paths.devRepoMode && !python.path.contains(Platform.pathSeparator)
        ? python.path // bare "python3" — resolve via PATH
        : python.path;

    try {
      _process = await Process.start(
        pythonCmd,
        [app.path],
        workingDirectory: paths.easelRoot.path,
        environment: env,
        runInShell: paths.devRepoMode,
      );
    } catch (e) {
      state = SidecarState.failed;
      lastError = 'Failed to spawn sidecar: $e';
      return;
    }

    _process!.stdout.transform(utf8.decoder).listen((chunk) {
      _log.write(chunk);
      if (_log.length > 80000) {
        final s = _log.toString();
        _log
          ..clear()
          ..write(s.substring(s.length - 40000));
      }
    });
    _process!.stderr.transform(utf8.decoder).listen((chunk) {
      _log.write(chunk);
    });
    unawaited(_process!.exitCode.then((code) {
      if (state == SidecarState.ready || state == SidecarState.starting) {
        state = SidecarState.failed;
        lastError = 'Sidecar exited with code $code';
      }
    }));

    final ok = await _waitHealthy(timeout: const Duration(seconds: 45));
    if (ok) {
      state = SidecarState.ready;
    } else {
      state = SidecarState.failed;
      lastError ??= 'Health check timed out on $baseUrl/api/health';
      await stop();
    }
  }

  Future<bool> _waitHealthy({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final resp = await http
            .get(Uri.parse('$baseUrl/api/health'))
            .timeout(const Duration(seconds: 2));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          if (body is Map && body['ok'] == true) return true;
        }
      } catch (_) {
        // retry
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  Future<void> stop() async {
    final proc = _process;
    _process = null;
    if (proc == null) {
      state = SidecarState.stopped;
      return;
    }
    proc.kill(ProcessSignal.sigterm);
    try {
      await proc.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      proc.kill(ProcessSignal.sigkill);
    }
    state = SidecarState.stopped;
  }

  static Future<int> _pickFreePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    // Prefer a stable-ish high port when possible for logs; still unique.
    if (port > 1024) return port;
    return 17000 + Random().nextInt(2000);
  }
}
