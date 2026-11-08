import 'dart:async';

import 'package:flutter/material.dart';

import '../api/easel_api.dart';

class EnvPage extends StatefulWidget {
  const EnvPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<EnvPage> createState() => _EnvPageState();
}

class _EnvPageState extends State<EnvPage> {
  bool _loading = true;
  String? _error;
  bool _packaged = false;
  bool _hostEnv = false;
  String? _modelsDir;
  List<EnvTool> _tools = [];
  String? _busyId;
  List<String> _jobLines = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({bool refresh = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.envTools(refresh: refresh);
      final tools = (data['tools'] as List? ?? [])
          .whereType<Map>()
          .map((e) => EnvTool(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _tools = tools;
        _packaged = data['packaged'] == true;
        _hostEnv = data['hostEnv'] == true;
        _modelsDir = data['modelsDir']?.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _reveal([String id = '']) async {
    try {
      await widget.api.revealEnv(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开文件夹：$e')),
      );
    }
  }

  Future<void> _install(EnvTool tool) async {
    if (_busyId != null) return;
    setState(() {
      _busyId = tool.id;
      _jobLines = ['开始安装 ${tool.name}…'];
    });
    try {
      final jobId = await widget.api.installTool(tool.id);
      while (mounted) {
        final job = await widget.api.installJob(jobId);
        final lines = (job['lines'] as List? ?? []).map((e) => '$e').toList();
        setState(() => _jobLines = lines.isEmpty ? _jobLines : lines);
        final state = '${job['state']}';
        if (state == 'ok' || state == 'fail') {
          if (state == 'fail' && mounted) {
            final detail = (job['result'] as Map?)?['detail'];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('安装失败：${detail ?? state}')),
            );
          }
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      await _reload(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reload, child: const Text('重试')),
          ],
        ),
      );
    }

    final groups = <String, List<EnvTool>>{};
    for (final t in _tools) {
      groups.putIfAbsent(t.groupName, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child:                 Text(
                  _packaged
                      ? '打包模式：运行时已内置；仅大模型等按需下载'
                      : (_hostEnv
                          ? '宿主机模式：使用本机 Python/Node 等；缺啥在此安装'
                          : '开发模式环境体检'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '打开模型目录',
                onPressed: () => _reveal('model'),
                icon: const Icon(Icons.folder_open_outlined),
              ),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        if (_modelsDir != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('模型目录：$_modelsDir',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        if (_busyId != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            height: 120,
            child: ListView(
              children: _jobLines
                  .map((l) => Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))
                  .toList(),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Text(entry.key,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                ...entry.value.map(_tile),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(EnvTool tool) {
    final ok = tool.state == 'ok';
    final canInstall = tool.onDemand || (!_packaged && !ok);
    final blockedBundled = _packaged && !tool.onDemand;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          color: ok ? Colors.green : Colors.orange,
        ),
        title: Text(tool.name),
        subtitle: Text([
          if (tool.version != null) tool.version!,
          if (tool.bundled) '已内置',
          if (tool.onDemand) '按需下载',
          if (tool.detail != null) tool.detail!,
          if (tool.big) '大件',
        ].where((e) => e.isNotEmpty).join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '在文件目录打开',
              onPressed: () => _reveal(tool.id),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
            ),
            if (blockedBundled)
              Text(ok ? '内置' : '缺失', style: Theme.of(context).textTheme.labelMedium)
            else if (canInstall)
              FilledButton.tonal(
                onPressed: (_busyId != null || ok && !tool.onDemand)
                    ? null
                    : () => _install(tool),
                child: Text(tool.id == 'model'
                    ? (ok ? '已下载' : '下载模型')
                    : (ok ? '已就绪' : '安装')),
              ),
          ],
        ),
      ),
    );
  }
}
