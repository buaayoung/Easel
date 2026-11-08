import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves vendor / data directories for the FastAPI sidecar.
class EaselPaths {
  EaselPaths({
    required this.vendorRoot,
    required this.easelRoot,
    required this.dataDir,
    required this.modelsDir,
    required this.openclawStateDir,
    this.devRepoMode = false,
    this.hostEnvMode = false,
  });

  final Directory vendorRoot;
  final Directory easelRoot;
  final Directory dataDir;
  final Directory modelsDir;
  final Directory openclawStateDir;

  /// Debug/profile against the git checkout + project `.venv`.
  final bool devRepoMode;

  /// Release DMG built with `PACKAGE_MODE=host`: bundled source, host toolchain,
  /// Application Support venv bootstrapped on first launch.
  final bool hostEnvMode;

  /// Uses host tools (dev checkout or host-mode DMG), not a relocatable vendor Python.
  bool get usesHostRuntime => devRepoMode || hostEnvMode;

  Directory get pythonBinDir => Directory(p.join(vendorRoot.path, 'python', 'bin'));

  /// Host-mode venv under Application Support (created by [HostBootstrap]).
  File get hostVenvPython => File(
        p.join(
          dataDir.path,
          'venv',
          Platform.isWindows ? r'Scripts\python.exe' : 'bin/python',
        ),
      );

  File get pythonExe {
    if (devRepoMode) {
      final fromEnv = Platform.environment['EASEL_PYTHON'];
      if (fromEnv != null && fromEnv.isNotEmpty) return File(fromEnv);
      final venvPy = File(
        p.join(
          easelRoot.path,
          '.venv',
          Platform.isWindows ? r'Scripts\python.exe' : 'bin/python',
        ),
      );
      if (venvPy.existsSync()) return venvPy;
      return File(Platform.isWindows ? 'python' : 'python3');
    }
    if (hostEnvMode) {
      final fromEnv = Platform.environment['EASEL_PYTHON'];
      if (fromEnv != null && fromEnv.isNotEmpty) return File(fromEnv);
      if (hostVenvPython.existsSync()) return hostVenvPython;
      return File(Platform.isWindows ? 'python' : 'python3');
    }
    final name = Platform.isWindows ? 'python.exe' : 'python';
    final primary = File(p.join(pythonBinDir.path, name));
    if (primary.existsSync()) return primary;
    final alt = File(p.join(pythonBinDir.path, 'python3'));
    if (alt.existsSync()) return alt;
    return primary;
  }

  /// Bare interpreter name resolved via PATH (host runtime before venv exists).
  bool get pythonResolvedViaPath =>
      usesHostRuntime && !pythonExe.path.contains(Platform.pathSeparator);

  File get webApp {
    if (devRepoMode) return File(p.join(easelRoot.path, 'web', 'app.py'));
    return File(p.join(vendorRoot.path, 'web', 'app.py'));
  }

  static Directory resolveOpenclawStateDir(Directory dataDir) {
    final override = Platform.environment['EASEL_OPENCLAW_STATE_DIR'];
    if (override != null && override.trim().isNotEmpty) {
      final d = Directory(override.trim());
      if (!d.existsSync()) d.createSync(recursive: true);
      return d;
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isNotEmpty) {
      final classic = Directory(p.join(home, '.openclaw-easel'));
      final identity = File(p.join(classic.path, 'identity', 'device.json'));
      final config = File(p.join(classic.path, 'openclaw.json'));
      if (classic.existsSync() &&
          (identity.existsSync() || config.existsSync())) {
        return classic;
      }
    }
    final fallback = Directory(p.join(dataDir.path, 'openclaw-state'));
    if (!fallback.existsSync()) fallback.createSync(recursive: true);
    return fallback;
  }

  static bool _isHostRuntimeBundle(Directory root) {
    if (File(p.join(root.path, '.runtime-host')).existsSync()) return true;
    final manifest = File(p.join(root.path, 'MANIFEST.json'));
    if (!manifest.existsSync()) return false;
    try {
      final data = jsonDecode(manifest.readAsStringSync());
      if (data is Map && '${data['runtime']}' == 'host') return true;
    } catch (_) {}
    return false;
  }

  static Future<EaselPaths> resolve() async {
    final resolved = await _resolveVendorOrRepo();
    final support = await getApplicationSupportDirectory();
    final dataDir = Directory(p.join(support.path, 'Easel'));
    if (!dataDir.existsSync()) dataDir.createSync(recursive: true);
    final openclawStateDir = resolveOpenclawStateDir(dataDir);

    if (resolved.devRepoMode) {
      final modelsDir = Directory(p.join(resolved.root.path, 'models'));
      if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);
      return EaselPaths(
        vendorRoot: resolved.root,
        easelRoot: resolved.root,
        dataDir: dataDir,
        modelsDir: modelsDir,
        openclawStateDir: openclawStateDir,
        devRepoMode: true,
      );
    }

    final modelsDir = Directory(p.join(dataDir.path, 'models'));
    if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);
    final easelRoot = Directory(p.join(resolved.root.path, 'easel-root'));
    return EaselPaths(
      vendorRoot: resolved.root,
      easelRoot: easelRoot.existsSync() ? easelRoot : resolved.root,
      dataDir: dataDir,
      modelsDir: modelsDir,
      openclawStateDir: openclawStateDir,
      hostEnvMode: resolved.hostEnvMode,
    );
  }

  static Future<({Directory root, bool devRepoMode, bool hostEnvMode})>
      _resolveVendorOrRepo() async {
    final fromEnv = Platform.environment['EASEL_VENDOR_ROOT'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final d = Directory(fromEnv);
      if (d.existsSync()) {
        return (
          root: d,
          devRepoMode: false,
          hostEnvMode: _isHostRuntimeBundle(d),
        );
      }
    }

    final preferHostRepo = !kReleaseMode &&
        Platform.environment['EASEL_FORCE_VENDOR'] != '1';
    if (preferHostRepo || Platform.environment['EASEL_DEV_REPO'] == '1') {
      final repo = _findRepoRoot();
      if (repo != null) {
        return (root: repo, devRepoMode: true, hostEnvMode: false);
      }
    }

    // Packaged Release / DMG: Contents/Resources/sidecar
    final exe = File(Platform.resolvedExecutable);
    final contents = exe.parent.parent;
    final bundled = Directory(p.join(contents.path, 'Resources', 'sidecar'));
    if (bundled.existsSync() &&
        File(p.join(bundled.path, 'web', 'app.py')).existsSync()) {
      return (
        root: bundled,
        devRepoMode: false,
        hostEnvMode: _isHostRuntimeBundle(bundled),
      );
    }

    for (final cursor in _searchRoots()) {
      for (final name in ['sidecar-host', 'sidecar']) {
        final candidate = Directory(p.join(cursor.path, 'dist', name));
        if (candidate.existsSync() &&
            File(p.join(candidate.path, 'web', 'app.py')).existsSync()) {
          return (
            root: candidate,
            devRepoMode: false,
            hostEnvMode: _isHostRuntimeBundle(candidate),
          );
        }
      }
      final repo = _repoAt(cursor);
      if (repo != null) {
        return (root: repo, devRepoMode: true, hostEnvMode: false);
      }
    }

    throw StateError(
      'Easel checkout / packaged sidecar not found. '
      'Run scripts/package_macos.sh (PACKAGE_MODE=full|host) or flutter run from the repo.',
    );
  }

  static Directory? _findRepoRoot() {
    for (final cursor in _searchRoots()) {
      final repo = _repoAt(cursor);
      if (repo != null) return repo;
    }
    return null;
  }

  static Directory? _repoAt(Directory cursor) {
    final repoApp = File(p.join(cursor.path, 'web', 'app.py'));
    final repoPkg = File(p.join(cursor.path, 'easel', 'vendor_paths.py'));
    if (repoApp.existsSync() && repoPkg.existsSync()) return cursor;
    return null;
  }

  static Iterable<Directory> _searchRoots() sync* {
    yield Directory.current;
    yield Directory(p.normalize(p.join(Directory.current.path, '..')));
    var cursor = Directory.current;
    for (var i = 0; i < 8; i++) {
      yield cursor;
      if (cursor.path == cursor.parent.path) break;
      cursor = cursor.parent;
    }
  }
}
