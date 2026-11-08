import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'host_bootstrap.dart';
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

    var python = paths.pythonExe;
    final app = paths.webApp;

    if (paths.hostEnvMode) {
      _log.writeln('hostEnvMode: bootstrapping Application Support venv…');
      final boot = HostBootstrap(paths);
      final result = await boot.ensure();
      _log.write(result.log);
      if (result.error != null || result.python == null) {
        state = SidecarState.failed;
        lastError = result.error ?? '宿主机环境安装失败';
        return;
      }
      python = result.python!;
    }

    if (!paths.pythonResolvedViaPath && !python.existsSync()) {
      state = SidecarState.failed;
      lastError = paths.usesHostRuntime
          ? 'Python missing: ${python.path}'
          : 'Vendor Python missing: ${python.path}';
      return;
    }
    if (!app.existsSync()) {
      state = SidecarState.failed;
      lastError = 'web/app.py missing: ${app.path}';
      return;
    }

    port = await _pickFreePort();
    final env = paths.hostEnvMode
        ? HostBootstrap(paths).hostEnvironment()
        : Map<String, String>.from(Platform.environment);
    env['EASEL_ROOT'] = paths.easelRoot.path;
    env['EASEL_MODELS_DIR'] = paths.modelsDir.path;
    env['EASEL_OPENCLAW_STATE_DIR'] = paths.openclawStateDir.path;
    env['EASEL_DATA_DIR'] = paths.dataDir.path;
    env['EASEL_PORT'] = '$port';
    env['EASEL_CHAT_TRANSPORT'] = env['EASEL_CHAT_TRANSPORT'] ?? 'http';
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
      env.remove('EASEL_VENDOR_ROOT');
      env.remove('EASEL_HOST_ENV');
      env.remove('PYTHONNOUSERSITE');
    } else if (paths.hostEnvMode) {
      env['EASEL_HOST_ENV'] = '1';
      env.remove('EASEL_PACKAGED');
      env.remove('PYTHONNOUSERSITE');
      // Point remotion / skill assets at the lite bundle without forcing packaged installs.
      env['EASEL_VENDOR_ROOT'] = paths.vendorRoot.path;
      final remotion = Directory(p.join(paths.vendorRoot.path, 'remotion-blueprint'));
      if (remotion.existsSync()) {
        env['EASEL_REMOTION_DIR'] = remotion.path;
      }
    } else {
      env['EASEL_VENDOR_ROOT'] = paths.vendorRoot.path;
      env['EASEL_PACKAGED'] = '1';
      env.remove('EASEL_HOST_ENV');
      env['PYTHONNOUSERSITE'] = '1';
    }

    if (!paths.pythonResolvedViaPath && python.existsSync()) {
      env['EASEL_PYTHON'] = python.path;
    }

    final pathKey = Platform.isWindows ? 'Path' : 'PATH';
    final sep = Platform.isWindows ? ';' : ':';
    final dataBin = Directory(p.join(paths.dataDir.path, 'bin'));
    if (!dataBin.existsSync()) dataBin.createSync(recursive: true);
    final prefixes = <String>[dataBin.path];
    if (paths.devRepoMode) {
      final venvBin = Directory(
        p.join(
          paths.easelRoot.path,
          '.venv',
          Platform.isWindows ? 'Scripts' : 'bin',
        ),
      );
      if (venvBin.existsSync()) prefixes.add(venvBin.path);
    } else if (paths.hostEnvMode) {
      final venvBin = Directory(
        p.join(paths.dataDir.path, 'venv', Platform.isWindows ? 'Scripts' : 'bin'),
      );
      if (venvBin.existsSync()) prefixes.add(venvBin.path);
    } else {
      prefixes.addAll([
        p.join(paths.vendorRoot.path, 'bin'),
        p.join(paths.vendorRoot.path, 'ffmpeg', 'bin'),
        p.join(paths.vendorRoot.path, 'node', 'bin'),
        p.join(paths.vendorRoot.path, 'node'),
        p.join(paths.vendorRoot.path, 'openclaw', 'node_modules', '.bin'),
        p.join(paths.vendorRoot.path, 'python', 'bin'),
        p.join(paths.vendorRoot.path, 'python', 'Scripts'),
      ]);
    }
    final existing = prefixes.where((d) => Directory(d).existsSync()).toList();
    if (existing.isNotEmpty) {
      env[pathKey] = [...existing, env[pathKey] ?? ''].join(sep);
    }

    _log.writeln('Starting sidecar on :$port');
    _log.writeln('python=${python.path}');
    _log.writeln('EASEL_PYTHON=${env['EASEL_PYTHON'] ?? ''}');
    _log.writeln('vendor=${paths.vendorRoot.path}');
    _log.writeln('easelRoot=${paths.easelRoot.path}');
    _log.writeln('devRepoMode=${paths.devRepoMode}');
    _log.writeln('hostEnvMode=${paths.hostEnvMode}');

    final useShell = paths.usesHostRuntime &&
        (paths.pythonResolvedViaPath || paths.hostEnvMode);
    final pythonCmd = paths.pythonResolvedViaPath ? python.path : python.path;

    try {
      _process = await Process.start(
        pythonCmd,
        [app.path],
        workingDirectory: paths.easelRoot.path,
        environment: env,
        runInShell: useShell && paths.pythonResolvedViaPath,
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

    final healthTimeout = paths.hostEnvMode
        ? const Duration(seconds: 90)
        : const Duration(seconds: 45);
    final ok = await _waitHealthy(timeout: healthTimeout);
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
    if (port > 1024) return port;
    return 17000 + Random().nextInt(2000);
  }
}
