import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/easel_modal.dart';
import '../widgets/page_scaffold.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({
    super.key,
    required this.api,
    this.onUseTopic,
  });

  final EaselApi api;
  final ValueChanged<String>? onUseTopic;

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  bool _ready = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _sources = [];
  List<String> _selected = [];
  List<Map<String, dynamic>> _groups = [];
  List<String> _warnings = [];
  int _updated = 0;
  final Set<String> _saved = {};
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    final id = ++_reqId;
    setState(() {
      _ready = false;
      _error = null;
      _loading = false;
    });
    try {
      final data = await widget.api.trendSources();
      if (!mounted || id != _reqId) return;
      final sources = (data['sources'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final warnings = (data['warnings'] as List? ?? []).map((e) => '$e').toList();
      final defaults = sources
          .where((s) => s['default'] == true)
          .map((s) => '${s['id']}')
          .where((id) => id.isNotEmpty)
          .toList();
      setState(() {
        _sources = sources;
        _warnings = warnings;
        _selected = defaults.isNotEmpty
            ? defaults
            : sources.map((s) => '${s['id']}').where((id) => id.isNotEmpty).take(3).toList();
        _ready = true;
      });
      await _loadTrends();
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _sources = [];
        _groups = [];
        _error = '$e';
        _ready = true;
      });
    }
  }

  Future<void> _loadTrends() async {
    if (_selected.isEmpty) {
      setState(() {
        _groups = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.trends(
        platforms: _selected.join(','),
        limit: 15,
      );
      if (!mounted || id != _reqId) return;
      final groups = (data['trends'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final warnings = (data['warnings'] as List? ?? []).map((e) => '$e').toList();
      setState(() {
        _groups = groups;
        _warnings = warnings;
        _updated = (data['updated'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected = _selected.where((x) => x != id).toList();
      } else {
        _selected = [..._selected, id];
      }
    });
    _loadTrends();
  }

  Future<void> _saveIdea(String platformLabel, Map<String, dynamic> item) async {
    final key = '$platformLabel:${item['id'] ?? item['title']}';
    if (_saved.contains(key)) return;
    try {
      await widget.api.createIdea({
        'title': '${item['title'] ?? '热点选题'}',
        'status': 'pending',
        'source': platformLabel,
      });
      setState(() => _saved.add(key));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入选题库')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('收藏失败：$e')));
      }
    }
  }

  String _hotText(Map<String, dynamic> item) {
    final hot = '${item['hot'] ?? ''}';
    if (hot.isNotEmpty) return hot;
    final heat = item['heat'];
    if (heat is Map) {
      final text = '${heat['text'] ?? ''}';
      if (text.isNotEmpty) return text;
      final value = heat['value'];
      final unit = '${heat['unit'] ?? ''}';
      if (value != null) return '$value$unit';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final updatedLabel = _updated > 0
        ? ' · ${DateTime.fromMillisecondsSinceEpoch(_updated * 1000).toLocal().hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(_updated * 1000).toLocal().minute.toString().padLeft(2, '0')} 查询'
        : '';

    return PageScaffold(
      title: '热点雷达',
      subtitle: '汇集平台热搜与自定义数据源$updatedLabel',
      actions: [
        IconButton(
          onPressed: _loading ? null : _discover,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
          tooltip: '刷新',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_sources.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in _sources)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: EaselChip(
                        label: '${s['label'] ?? s['id']}',
                        selected: _selected.contains('${s['id']}'),
                        onTap: () => _toggle('${s['id']}'),
                      ),
                    ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: EaselColors.red, fontSize: 13)),
          ],
          for (final w in _warnings) ...[
            const SizedBox(height: 6),
            Text(w, style: const TextStyle(color: EaselColors.amber, fontSize: 12.5)),
          ],
          if (!_ready) ...[
            const SizedBox(height: 24),
            const Center(child: Text('正在加载数据源…', style: TextStyle(color: EaselColors.textSecondary))),
          ] else if (_sources.isEmpty) ...[
            const SizedBox(height: 24),
            const Center(
              child: Text('尚未启用数据源，请在本地热点数据源配置中添加或启用。',
                  style: TextStyle(color: EaselColors.textSecondary)),
            ),
          ] else if (_selected.isEmpty) ...[
            const SizedBox(height: 24),
            const Center(
              child: Text('请选择上方的数据源查看热点。', style: TextStyle(color: EaselColors.textSecondary)),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _loading && _groups.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        itemCount: _groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final g = _groups[i];
                          final label = '${g['label'] ?? g['platform'] ?? ''}';
                          final items = (g['items'] as List? ?? [])
                              .whereType<Map>()
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList();
                          final ok = g['ok'] == true;
                          final err = g['error'];
                          final errMsg = err is Map ? '${err['message'] ?? ''}' : '';
                          return EaselCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(width: 8),
                                    Text('${items.length}',
                                        style: const TextStyle(fontSize: 12, color: EaselColors.textTertiary)),
                                    const Spacer(),
                                    if (_loading)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                  ],
                                ),
                                if (errMsg.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(errMsg, style: const TextStyle(fontSize: 12, color: EaselColors.amber)),
                                ],
                                const SizedBox(height: 8),
                                if (items.isEmpty)
                                  Text(
                                    !ok ? '该数据源暂时不可用' : '采集成功，暂无热点',
                                    style: const TextStyle(fontSize: 13, color: EaselColors.textSecondary),
                                  )
                                else
                                  for (var idx = 0; idx < items.length; idx++)
                                    _itemRow(label, items[idx], idx),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(String platformLabel, Map<String, dynamic> item, int index) {
    final title = '${item['title'] ?? '未命名'}';
    final hot = _hotText(item);
    final key = '$platformLabel:${item['id'] ?? title}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: index < 3 ? EaselColors.accentStart : EaselColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                if (hot.isNotEmpty)
                  Text(hot, style: const TextStyle(fontSize: 12, color: EaselColors.textTertiary)),
              ],
            ),
          ),
          IconButton(
            tooltip: _saved.contains(key) ? '已收藏' : '收藏到选题库',
            onPressed: () => _saveIdea(platformLabel, item),
            icon: Icon(
              _saved.contains(key) ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              color: _saved.contains(key) ? EaselColors.accentEnd : EaselColors.textTertiary,
            ),
          ),
          if (widget.onUseTopic != null)
            TextButton(
              onPressed: () => widget.onUseTopic!(title),
              child: const Text('做内容', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
