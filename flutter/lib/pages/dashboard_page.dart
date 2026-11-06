import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../models/chat_session.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api, required this.onNavigate});

  final EaselApi api;
  final ValueChanged<AppPage> onNavigate;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  int _trends = 0;
  int _ideas = 0;
  int _schedule = 0;
  int _outputs = 0;
  int _accounts = 0;

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
      final trendsFut = widget.api.trends(limit: 8);
      final rest = await Future.wait([
        widget.api.ideas(),
        widget.api.schedule(),
        widget.api.outputs(),
        widget.api.accounts(),
      ]);
      var trendCount = 0;
      try {
        final trends = await trendsFut;
        final groups = (trends['trends'] as List? ?? []);
        for (final g in groups.whereType<Map>()) {
          final items = g['items'];
          if (items is List) trendCount += items.length;
        }
      } catch (_) {
        trendCount = 0;
      }
      setState(() {
        _trends = trendCount;
        _ideas = rest[0].length;
        _schedule = rest[1].length;
        _outputs = rest[2].length;
        _accounts = rest[3].length;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '工作台',
      subtitle: '热点 · 选题 · 排期 · 发布一览',
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _quick(
                      '热点雷达',
                      Icons.local_fire_department_outlined,
                      AppPage.trends,
                    ),
                    _quick('选题库', Icons.lightbulb_outline, AppPage.ideas),
                    _quick(
                      '内容日历',
                      Icons.calendar_month_outlined,
                      AppPage.calendar,
                    ),
                    _quick('发布中心', Icons.send_outlined, AppPage.publish),
                    _quick('爆款拆解', Icons.analytics_outlined, AppPage.breakdown),
                    _quick('去对话', Icons.chat_bubble_outline, AppPage.chat),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _stat('热点', '$_trends', AppPage.trends),
                    _stat('选题', '$_ideas', AppPage.ideas),
                    _stat('排期', '$_schedule', AppPage.calendar),
                    _stat('产物', '$_outputs', AppPage.outputs),
                    _stat('账号', '$_accounts', AppPage.accounts),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _quick(String label, IconData icon, AppPage page) {
    return EaselCard(
      onTap: () => widget.onNavigate(page),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: EaselColors.accentStart),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, AppPage page) {
    return SizedBox(
      width: 160,
      child: EaselCard(
        onTap: () => widget.onNavigate(page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: EaselColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
