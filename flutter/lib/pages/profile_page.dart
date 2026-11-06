import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    this.onChanged,
    this.onNewProfile,
  });

  final EaselApi api;
  final VoidCallback? onChanged;
  final VoidCallback? onNewProfile;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _personas = [];
  String? _selected;
  List<Map<String, dynamic>> _files = [];
  String? _fileName;
  final _editor = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final personas = await widget.api.personas();
      setState(() {
        _personas = personas;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _open(String name) async {
    setState(() {
      _selected = name;
      _files = [];
      _fileName = null;
      _editor.clear();
    });
    try {
      final data = await widget.api.personaFiles(name);
      final files = (data['files'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() => _files = files);
      if (files.isNotEmpty) {
        await _openFile(files.first);
      }
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final name = '${file['name'] ?? file['filename'] ?? ''}';
    setState(() {
      _fileName = name;
      _editor.text = '${file['content'] ?? ''}';
    });
  }

  Future<void> _save() async {
    final persona = _selected;
    final file = _fileName;
    if (persona == null || file == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.savePersonaFile(persona, file, _editor.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存')));
      }
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete(String name) async {
    await widget.api.deletePersona(name);
    if (_selected == name) {
      _selected = null;
      _files = [];
      _fileName = null;
      _editor.clear();
    }
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '画像',
      subtitle: '管理多套用户画像与维度文件',
      actions: [
        FilledButton.icon(
          onPressed: widget.onNewProfile,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('新建画像'),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      padding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Row(
              children: [
                SizedBox(
                  width: 280,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 12, 24),
                    children: [
                      if (_personas.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '暂无画像。点击「新建画像」打开配置向导。',
                              style: TextStyle(
                                color: EaselColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: widget.onNewProfile,
                              child: const Text('配置账号画像'),
                            ),
                          ],
                        ),
                      for (final p in _personas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: EaselCard(
                            onTap: () => _open('${p['name']}'),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: EaselColors.accentSoft,
                                    borderRadius: BorderRadius.circular(
                                      EaselColors.radius,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.badge_outlined,
                                    color: EaselColors.accentStart,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${p['name']}',
                                    style: TextStyle(
                                      fontWeight: _selected == '${p['name']}'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _delete('${p['name']}'),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _selected == null
                      ? Center(
                          child: Text(
                            '选择左侧画像查看维度文件',
                            style: TextStyle(color: EaselColors.textSecondary),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _selected!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final f in _files)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(
                                            '${f['name'] ?? f['filename']}',
                                          ),
                                          selected:
                                              _fileName ==
                                              '${f['name'] ?? f['filename']}',
                                          onSelected: (_) => _openFile(f),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: TextField(
                                  controller: _editor,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: const InputDecoration(
                                    alignLabelWithHint: true,
                                    hintText: 'Markdown 内容…',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: _saving || _fileName == null
                                      ? null
                                      : _save,
                                  child: Text(_saving ? '保存中…' : '保存'),
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
