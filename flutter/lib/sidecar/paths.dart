import 'dart:io';

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
  });

  final Directory vendorRoot;
  final Directory easelRoot;
  final Directory dataDir;
  final Directory modelsDir;
  final Directory openclawStateDir;

  /// When true, use system/current Python against the git checkout (no dist/sidecar).
  final bool devRepoMode;

  Directory get pythonBinDir => Directory(p.join(vendorRoot.path, 'python', 'bin'));
  File get pythonExe {
    if (devRepoMode) {
      final fromEnv = Platform.environment['EASEL_PYTHON'];
      if (fromEnv != null && fromEnv.isNotEmpty) return File(fromEnv);
      return File(Platform.isWindows ? 'python' : 'python3');
    }
    final name = Platform.isWindows ? 'python.exe' : 'python';
    final primary = File(p.join(pythonBinDir.path, name));
    if (primary.existsSync()) return primary;
    final alt = File(p.join(pythonBinDir.path, 'python3'));
    if (alt.existsSync()) return alt;
    return primary;
  }

  File get webApp {
    if (devRepoMode) return File(p.join(easelRoot.path, 'web', 'app.py'));
    return File(p.join(vendorRoot.path, 'web', 'app.py'));
  }

  static Future<EaselPaths> resolve() async {
    final resolved = await _resolveVendorOrRepo();
    final support = await getApplicationSupportDirectory();
    final dataDir = Directory(p.join(support.path, 'Easel'));
    final modelsDir = Directory(p.join(dataDir.path, 'models'));
    final openclawStateDir = Directory(p.join(dataDir.path, 'openclaw-state'));
    for (final d in [dataDir, modelsDir, openclawStateDir]) {
      if (!d.existsSync()) d.createSync(recursive: true);
    }
    if (resolved.devRepoMode) {
      return EaselPaths(
        vendorRoot: resolved.root,
        easelRoot: resolved.root,
        dataDir: dataDir,
        modelsDir: modelsDir,
        openclawStateDir: openclawStateDir,
        devRepoMode: true,
      );
    }
    final easelRoot = Directory(p.join(resolved.root.path, 'easel-root'));
    return EaselPaths(
      vendorRoot: resolved.root,
      easelRoot: easelRoot.existsSync() ? easelRoot : resolved.root,
      dataDir: dataDir,
      modelsDir: modelsDir,
      openclawStateDir: openclawStateDir,
    );
  }

  static Future<({Directory root, bool devRepoMode})> _resolveVendorOrRepo() async {
    final fromEnv = Platform.environment['EASEL_VENDOR_ROOT'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final d = Directory(fromEnv);
      if (d.existsSync()) return (root: d, devRepoMode: false);
    }

    // Packaged macOS: Contents/Resources/sidecar
    final exe = File(Platform.resolvedExecutable);
    final contents = exe.parent.parent; // .../Contents/MacOS -> Contents
    final bundled = Directory(p.join(contents.path, 'Resources', 'sidecar'));
    if (bundled.existsSync()) return (root: bundled, devRepoMode: false);

    // Xcode/Flutter resource copy location during debug
    final runnerResources = Directory(p.join(
      Directory.current.path,
      'macos',
      'Runner',
      'Resources',
      'sidecar',
    ));
    if (runnerResources.existsSync()) {
      return (root: runnerResources, devRepoMode: false);
    }

    for (final cursor in _searchRoots()) {
      final candidate = Directory(p.join(cursor.path, 'dist', 'sidecar'));
      if (candidate.existsSync() &&
          File(p.join(candidate.path, 'web', 'app.py')).existsSync()) {
        return (root: candidate, devRepoMode: false);
      }
      final repoApp = File(p.join(cursor.path, 'web', 'app.py'));
      final repoPkg = File(p.join(cursor.path, 'easel', 'vendor_paths.py'));
      if (repoApp.existsSync() && repoPkg.existsSync()) {
        return (root: cursor, devRepoMode: true);
      }
    }

    throw StateError(
      'EASEL_VENDOR_ROOT not found. Run scripts/bundle_sidecar.sh '
      'or open the app from the Easel repo / set EASEL_VENDOR_ROOT.',
    );
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
