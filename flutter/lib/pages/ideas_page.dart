import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class IdeasPage extends StatefulWidget {
  const IdeasPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<IdeasPage> createState() => _IdeasPageState();
}

class _IdeasPageState extends State<IdeasPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
      final items = await widget.api.ideas();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建选题'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '选题标题')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await widget.api.createIdea({'title': ctrl.text.trim(), 'status': 'todo'});
    await _load();
  }

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    final id = '${item['id']}';
    await widget.api.updateIdea(id, {...item, 'status': status});
    await _load();
  }

  Future<void> _delete(String id) async {
    await widget.api.deleteIdea(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cols = {
      'todo': _items.where((e) => '${e['status']}' == 'todo' || '${e['status']}'.isEmpty).toList(),
      'doing': _items.where((e) => '${e['status']}' == 'doing' || '${e['status']}' == 'in_progress').toList(),
      'done': _items.where((e) => '${e['status']}' == 'done' || '${e['status']}' == 'completed').toList(),
    };

    return PageScaffold(
      title: '选题库',
      subtitle: '待做 / 进行中 / 完成',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        FilledButton.tonal(onPressed: _add, child: const Text('新建')),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in [
                      ('todo', '待做'),
                      ('doing', '进行中'),
                      ('done', '完成'),
                    ])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: EaselColors.surface2,
                            borderRadius: BorderRadius.circular(EaselColors.radiusLg),
                            border: Border.all(color: EaselColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView(
                                  children: [
                                    for (final it in cols[entry.$1]!)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: EaselCard(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${it['title'] ?? '未命名'}',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 4,
                                                children: [
                                                  if (entry.$1 != 'doing')
                                                    TextButton(
                                                      onPressed: () => _setStatus(it, 'doing'),
                                                      child: const Text('进行中', style: TextStyle(fontSize: 12)),
                                                    ),
                                                  if (entry.$1 != 'done')
                                                    TextButton(
                                                      onPressed: () => _setStatus(it, 'done'),
                                                      child: const Text('完成', style: TextStyle(fontSize: 12)),
                                                    ),
                                                  if (entry.$1 != 'todo')
                                                    TextButton(
                                                      onPressed: () => _setStatus(it, 'todo'),
                                                      child: const Text('待做', style: TextStyle(fontSize: 12)),
                                                    ),
                                                  IconButton(
                                                    onPressed: () => _delete('${it['id']}'),
                                                    icon: const Icon(Icons.delete_outline, size: 16),
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
