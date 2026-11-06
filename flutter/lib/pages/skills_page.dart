import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _skills = [];
  String _query = '';
  Map<String, dynamic>? _selected;
  final _input = TextEditingController();
  bool _running = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final skills = await widget.api.skills();
      setState(() {
        _skills = skills;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _open(Map<String, dynamic> skill) async {
    final name = '${skill['name'] ?? skill['id'] ?? ''}';
    try {
      final detail = await widget.api.skillDetail(name);
      setState(() {
        _selected = {...skill, ...detail};
        _result = '';
        _input.clear();
      });
    } catch (_) {
      setState(() {
        _selected = skill;
        _result = '';
      });
    }
  }

  Future<void> _run() async {
    final sel = _selected;
    if (sel == null || _running) return;
    final name = '${sel['name'] ?? sel['id'] ?? ''}';
    setState(() {
      _running = true;
      _result = '';
    });
    try {
      final res = await widget.api.executeSkill(name, _input.text.trim());
      setState(() => _result = '${res['response'] ?? res['result'] ?? res['output'] ?? res}');
    } catch (e) {
      setState(() => _result = '失败：$e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _skills.where((s) {
      if (_query.isEmpty) return true;
      final blob = '${s['name']} ${s['description'] ?? s['desc'] ?? s['layer'] ?? ''}'.toLowerCase();
      return blob.contains(_query.toLowerCase());
    }).toList();

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final s in filtered) {
      final layer = '${s['layer'] ?? s['group'] ?? '通用'}';
      groups.putIfAbsent(layer, () => []).add(s);
    }

    return PageScaffold(
      title: '技能库',
      subtitle: '按能力层浏览、配置并执行技能',
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      padding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 12, 24),
                        child: Column(
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search, size: 18),
                                hintText: '搜索技能…',
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView(
                                children: [
                                  for (final entry in groups.entries) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                                      child: Text(entry.key,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700, color: EaselColors.textSecondary)),
                                    ),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final s in entry.value)
                                          SizedBox(
                                            width: 260,
                                            child: EaselCard(
                                              onTap: () => _open(s),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('${s['name'] ?? s['id']}',
                                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '${s['description'] ?? s['desc'] ?? ''}',
                                                    maxLines: 3,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 12.5, color: EaselColors.textSecondary, height: 1.4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selected != null)
                      Container(
                        width: 360,
                        decoration: const BoxDecoration(
                          border: Border(left: BorderSide(color: EaselColors.border)),
                          color: EaselColors.surface,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${_selected!['name'] ?? _selected!['id']}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _selected = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            Text('${_selected!['description'] ?? _selected!['desc'] ?? ''}',
                                style: const TextStyle(fontSize: 12.5, color: EaselColors.textSecondary)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _input,
                              minLines: 4,
                              maxLines: 8,
                              decoration: const InputDecoration(hintText: '输入技能参数 / 指令…'),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: _running ? null : _run,
                              child: Text(_running ? '执行中…' : '运行'),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _result.isEmpty ? '运行结果会显示在这里' : _result,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _result.isEmpty ? EaselColors.textTertiary : EaselColors.text,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
