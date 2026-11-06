import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

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
      final items = await widget.api.schedule();
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
    final title = TextEditingController();
    final date = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建排期'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: '标题')),
            const SizedBox(height: 8),
            TextField(controller: date, decoration: const InputDecoration(labelText: '日期 YYYY-MM-DD')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await widget.api.createSchedule({
      'title': title.text.trim(),
      'date': date.text.trim(),
      'status': 'planned',
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final startOffset = (first.weekday % 7); // Sun=0 style
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    return PageScaffold(
      title: '内容日历',
      subtitle: '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
      actions: [
        IconButton(
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        FilledButton.tonal(onPressed: _add, child: const Text('新建')),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Row(
                      children: [
                        for (final d in ['日', '一', '二', '三', '四', '五', '六'])
                          Expanded(
                            child: Center(
                              child: Text(d,
                                  style: TextStyle(
                                      fontSize: 12, color: EaselColors.textTertiary, fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                        itemCount: 42,
                        itemBuilder: (_, i) {
                          final dayNum = i - startOffset + 1;
                          if (dayNum < 1 || dayNum > daysInMonth) {
                            return const SizedBox.shrink();
                          }
                          final dateStr =
                              '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                          final dayItems = _items.where((e) {
                            final d = '${e['date'] ?? e['day'] ?? ''}';
                            return d.startsWith(dateStr);
                          }).toList();
                          return Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: EaselColors.surface2,
                              borderRadius: BorderRadius.circular(EaselColors.radius),
                              border: Border.all(color: EaselColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$dayNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                for (final it in dayItems.take(2))
                                  Text(
                                    '${it['title'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, color: EaselColors.accentEnd),
                                  ),
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
}
