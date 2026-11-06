import 'package:flutter/material.dart';

import '../theme/easel_theme.dart';
import '../theme/theme_controller.dart';

/// Web `.theme-toggle` — sits next to the brand title (margin-left: auto).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final dark = controller.isDark(context);
    return Tooltip(
      message: dark ? '切换到日间模式' : '切换到夜间模式',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.toggle(context),
          borderRadius: BorderRadius.circular(EaselColors.radius),
          hoverColor: EaselColors.surfaceHover,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: EaselColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
