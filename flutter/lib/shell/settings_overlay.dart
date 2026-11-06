import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../pages/settings_page.dart';
import '../theme/easel_theme.dart';

class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({
    super.key,
    required this.api,
    this.banner,
    required this.onClose,
    this.onConfigured,
  });

  final EaselApi api;
  final String? banner;
  final VoidCallback onClose;
  final VoidCallback? onConfigured;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Light: rgba(23,25,28,0.38); dark: rgba(0,0,0,0.6)
      color: EaselColors.isDark
          ? const Color(0x99000000)
          : const Color(0x6117191C),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 680),
          child: FractionallySizedBox(
            widthFactor: 0.94,
            heightFactor: 0.92,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: EaselColors.bg,
                borderRadius: BorderRadius.circular(EaselColors.radiusXl),
                border: Border.all(color: EaselColors.border),
                boxShadow: EaselColors.shadowLg,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(EaselColors.radiusXl),
                child: Column(
                  children: [
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: EaselColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '设置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                            tooltip: '关闭',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SettingsPage(
                        api: api,
                        banner: banner,
                        onConfigured: onConfigured,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
