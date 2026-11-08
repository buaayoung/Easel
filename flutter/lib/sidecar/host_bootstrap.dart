import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'paths.dart';

/// First-launch bootstrap for PACKAGE_MODE=host DMGs: create Application
/// Support venv and install the bundled easel package via uv/pip.
class HostBootstrap {
  HostBootstrap(this.paths);

  final EaselPaths paths;

  Directory get venvDir => Directory(p.join(paths.dataDir.path, 'venv'));
  File get venvPython => File(
        p.join(
          venvDir.path,
          Platform.isWindows ? r'Scripts\python.exe' : 'bin/python',
        ),
      );

  /// Augment PATH so GUI-launched apps find Homebrew / uv / nvm.
  Map<String, String> hostEnvironment([Map<String, String>? base]) {
    final env = Map<String, String>.from(base ?? Platform.environment);
    final pathKey = Platform.isWindows ? 'Path' : 'PATH';
    final sep = Platform.isWindows ? ';' : ':';
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    final prefixes = <String>[
      p.join(paths.dataDir.path, 'bin'),
      if (home.isNotEmpty) p.join(home, '.local', 'bin'),
      if (home.isNotEmpty) p.join(home, '.cargo', 'bin'),
      '/opt/homebrew/bin',
      '/opt/homebrew/sbin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
    ];
    // Latest nvm node bin if present.
    if (home.isNotEmpty) {
      final nvmVersions = Directory(p.join(home, '.nvm', 'versions', 'node'));
      if (nvmVersions.existsSync()) {
        final kids = nvmVersions
            .listSync()
            .whereType<Directory>()
            .map((d) => p.join(d.path, 'bin'))
            .where((b) => Directory(b).existsSync())
            .toList()
          ..sort();
        if (kids.isNotEmpty) prefixes.insert(1, kids.last);
      }
    }
    final existing = prefixes.where((d) => Directory(d).existsSync()).toList();
    env[pathKey] = [...existing, env[pathKey] ?? ''].join(sep);
    env['EASEL_HOST_ENV'] = '1';
    env['EASEL_DATA_DIR'] = paths.dataDir.path;
    env['EASEL_ROOT'] = paths.easelRoot.path;
    env.remove('EASEL_PACKAGED');
    return env;
  }

  Future<bool> _fastapiOk(File py) async {
    if (!py.existsSync()) return false;
    try {
      final r = await Process.run(
        py.path,
        ['-c', 'import fastapi, easel; print("ok")'],
        environment: hostEnvironment(),
        runInShell: false,
      );
      return r.exitCode == 0 && '${r.stdout}'.contains('ok');
    } catch (_) {
      return false;
    }
  }

  Future<String?> _which(String name, Map<String, String> env) async {
    try {
      final r = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [name],
        environment: env,
        runInShell: true,
      );
      if (r.exitCode != 0) return null;
      final line = '${r.stdout}'.trim().split(RegExp(r'\r?\n')).first.trim();
      return line.isEmpty ? null : line;
    } catch (_) {
      return null;
    }
  }

  /// Ensure venv exists with easel deps. Returns python to use, or null + error.
  Future<({File? python, String log, String? error})> ensure() async {
    final buf = StringBuffer();
    void log(String m) {
      buf.writeln(m);
    }

    if (await _fastapiOk(venvPython)) {
      log('host venv ready: ${venvPython.path}');
      return (python: venvPython, log: buf.toString(), error: null);
    }

    final env = hostEnvironment();
    final uv = await _which('uv', env);
    final py3 = await _which('python3', env) ?? await _which('python', env);
    if (uv == null && py3 == null) {
      return (
        python: null,
        log: buf.toString(),
        error: '未找到 uv 或 python3。请先安装 Python 3.10+（或 uv），然后重试。',
      );
    }

    final easelRoot = paths.easelRoot.path;
    final pyproject = File(p.join(easelRoot, 'pyproject.toml'));
    if (!pyproject.existsSync()) {
      return (
        python: null,
        log: buf.toString(),
        error: '缺少 pyproject.toml：$easelRoot',
      );
    }

    log('Bootstrapping host venv → ${venvDir.path}');
    try {
      if (venvDir.existsSync()) {
        // Incomplete previous attempt — recreate.
        venvDir.deleteSync(recursive: true);
      }
      if (uv != null) {
        log('uv venv ($uv)');
        var r = await Process.run(
          uv,
          ['venv', '--python', '3.13', venvDir.path],
          environment: env,
          runInShell: false,
        );
        if (r.exitCode != 0) {
          // Fall back to default python discovery.
          r = await Process.run(
            uv,
            ['venv', venvDir.path],
            environment: env,
            runInShell: false,
          );
        }
        if (r.exitCode != 0) {
          log('uv venv failed: ${r.stderr}');
          return (
            python: null,
            log: buf.toString(),
            error: 'uv venv 失败：${'${r.stderr}'.trim()}',
          );
        }
        log('uv pip install -e easel-root');
        final index = Platform.environment['EASEL_PIP_INDEX'] ??
            'https://pypi.tuna.tsinghua.edu.cn/simple';
        r = await Process.run(
          uv,
          [
            'pip',
            'install',
            '--python',
            venvPython.path,
            'pip',
            '-e',
            easelRoot,
            '-i',
            index,
          ],
          environment: env,
          runInShell: false,
        );
        log('${r.stdout}');
        if (r.exitCode != 0) {
          log('${r.stderr}');
          return (
            python: null,
            log: buf.toString(),
            error: 'uv pip install 失败：${'${r.stderr}'.trim().split('\n').last}',
          );
        }
      } else {
        log('python -m venv ($py3)');
        var r = await Process.run(
          py3!,
          ['-m', 'venv', venvDir.path],
          environment: env,
          runInShell: false,
        );
        if (r.exitCode != 0) {
          return (
            python: null,
            log: buf.toString(),
            error: '创建 venv 失败：${'${r.stderr}'.trim()}',
          );
        }
        final index = Platform.environment['EASEL_PIP_INDEX'] ??
            'https://pypi.tuna.tsinghua.edu.cn/simple';
        log('pip install -e easel-root');
        r = await Process.run(
          venvPython.path,
          [
            '-m',
            'pip',
            'install',
            '-U',
            'pip',
            'wheel',
            'setuptools',
            '-i',
            index,
          ],
          environment: env,
          runInShell: false,
        );
        r = await Process.run(
          venvPython.path,
          ['-m', 'pip', 'install', '-e', easelRoot, '-i', index],
          environment: env,
          runInShell: false,
        );
        log('${r.stdout}');
        if (r.exitCode != 0) {
          log('${r.stderr}');
          return (
            python: null,
            log: buf.toString(),
            error: 'pip install 失败：${'${r.stderr}'.trim().split('\n').last}',
          );
        }
      }
    } catch (e) {
      return (python: null, log: buf.toString(), error: '引导安装异常：$e');
    }

    if (!await _fastapiOk(venvPython)) {
      return (
        python: null,
        log: buf.toString(),
        error: 'venv 已创建但无法 import fastapi/easel，请检查网络后重试。',
      );
    }
    log('host venv ready: ${venvPython.path}');
    // Stamp for diagnostics.
    File(p.join(venvDir.path, '.unisyn-host-ready')).writeAsStringSync(
      jsonEncode({
        'at': DateTime.now().toUtc().toIso8601String(),
        'easelRoot': easelRoot,
      }),
    );
    return (python: venvPython, log: buf.toString(), error: null);
  }
}
