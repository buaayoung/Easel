import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../theme/easel_theme.dart';

const _tools = <(AppPage, IconData, String)>[
  (AppPage.trends, Icons.local_fire_department_outlined, '热点雷达'),
  (AppPage.ideas, Icons.lightbulb_outline, '选题库'),
  (AppPage.calendar, Icons.calendar_month_outlined, '内容日历'),
  (AppPage.publish, Icons.send_outlined, '发布中心'),
  (AppPage.breakdown, Icons.analytics_outlined, '爆款拆解'),
];

class EaselSubNav extends StatelessWidget {
  const EaselSubNav({
    super.key,
    required this.current,
    required this.onNavigate,
  });

  final AppPage current;
  final ValueChanged<AppPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: EaselColors.border)),
        color: EaselColors.surface,
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => onNavigate(AppPage.dashboard),
            icon: const Icon(Icons.grid_view_rounded, size: 15),
            label: const Text('工作台'),
            style: TextButton.styleFrom(foregroundColor: EaselColors.textSecondary),
          ),
          Container(width: 1, height: 18, color: EaselColors.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (page, icon, label) in _tools)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton.icon(
                        onPressed: () => onNavigate(page),
                        icon: Icon(icon, size: 14),
                        label: Text(label),
                        style: TextButton.styleFrom(
                          foregroundColor: current == page ? EaselColors.text : EaselColors.textSecondary,
                          backgroundColor: current == page ? EaselColors.accentSoft : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(EaselColors.radius),
                          ),
                        ),
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
