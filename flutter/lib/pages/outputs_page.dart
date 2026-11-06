import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class OutputsPage extends StatefulWidget {
  const OutputsPage({super.key, required this.api, this.jumpPath});

  final EaselApi api;
  final String? jumpPath;

  @override
  State<OutputsPage> createState() => _OutputsPageState();
}

class _OutputsPageState extends State<OutputsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _roots = [];
  final List<Map<String, dynamic>> _stack = [];
  String? _previewPath;
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roots = await widget.api.outputs();
      setState(() {
        _roots = roots;
        _stack.clear();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _current {
    if (_stack.isEmpty) return _roots;
    final last = _stack.last;
    final children = last['children'];
    if (children is List) {
      return children.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Future<void> _open(Map<String, dynamic> node) async {
    final isDir = node['type'] == 'dir' || node['children'] is List;
    if (isDir) {
      setState(() => _stack.add(node));
      return;
    }
    final path = '${node['path'] ?? node['name'] ?? ''}';
    try {
      final content = await widget.api.outputContent(path);
      setState(() {
        _previewPath = path;
        _preview = '${content['content'] ?? content['text'] ?? content}';
      });
    } catch (e) {
      setState(() {
        _previewPath = path;
        _preview = '无法预览：$e';
      });
    }
  }

  Future<void> _delete(String path) async {
    await widget.api.deleteOutput(path);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '内容库',
      subtitle: '浏览与管理生成产物',
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _stack.isEmpty
                              ? null
                              : () => setState(() {
                                    _stack.clear();
                                  }),
                          child: const Text('根目录'),
                        ),
                        for (var i = 0; i < _stack.length; i++)
                          TextButton(
                            onPressed: () => setState(() {
                              _stack.removeRange(i + 1, _stack.length);
                            }),
                            child: Text('${_stack[i]['name'] ?? _stack[i]['path'] ?? ''}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: _current.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (_, i) {
                                final n = _current[i];
                                final name = '${n['name'] ?? n['path'] ?? ''}';
                                final isDir = n['type'] == 'dir' || n['children'] is List;
                                return EaselCard(
                                  onTap: () => _open(n),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                                          size: 18, color: EaselColors.accentStart),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(name)),
                                      if (!isDir)
                                        IconButton(
                                          onPressed: () => _delete('${n['path'] ?? name}'),
                                          icon: const Icon(Icons.delete_outline, size: 16),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_previewPath != null) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 360,
                              child: EaselCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(_previewPath!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ),
                                        IconButton(
                                          onPressed: () => setState(() {
                                            _previewPath = null;
                                            _preview = '';
                                          }),
                                          icon: const Icon(Icons.close, size: 16),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: SelectableText(_preview, style: const TextStyle(fontSize: 12.5, height: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
