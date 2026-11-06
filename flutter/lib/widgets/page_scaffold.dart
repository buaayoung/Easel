import 'package:flutter/material.dart';

import '../theme/easel_theme.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: EaselColors.text,
                        )),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: const TextStyle(fontSize: 13.5, color: EaselColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        Expanded(child: Padding(padding: padding, child: child)),
      ],
    );
  }
}

class EaselCard extends StatelessWidget {
  const EaselCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: EaselColors.surface,
        borderRadius: BorderRadius.circular(EaselColors.radiusLg),
        border: Border.all(color: EaselColors.border),
        boxShadow: EaselColors.shadowSm,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EaselColors.radiusLg),
        child: body,
      ),
    );
  }
}
