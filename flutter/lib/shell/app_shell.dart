import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../pages/accounts_page.dart';
import '../pages/breakdown_page.dart';
import '../pages/calendar_page.dart';
import '../pages/chat_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/ideas_page.dart';
import '../pages/outputs_page.dart';
import '../pages/profile_page.dart';
import '../pages/publish_page.dart';
import '../pages/skills_page.dart';
import '../pages/trends_page.dart';
import '../theme/easel_theme.dart';
import '../widgets/onboarding_wizard.dart';
import 'app_controller.dart';
import 'settings_overlay.dart';
import 'sidebar.dart';
import 'sub_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  bool get _showSubNav => const {
        AppPage.trends,
        AppPage.ideas,
        AppPage.calendar,
        AppPage.publish,
        AppPage.breakdown,
      }.contains(controller.currentPage);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Stack(
      children: [
        Row(
          children: [
            EaselSidebar(controller: c),
            Expanded(
              child: mainContentBackground(
                child: Column(
                  children: [
                    if (_showSubNav)
                      EaselSubNav(current: c.currentPage, onNavigate: c.setPage),
                    Expanded(child: _page(c)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (c.settingsOpen && c.api != null)
          SettingsOverlay(
            api: c.api!,
            banner: c.modelConfigured
                ? null
                : '尚未配置可用模型鉴权。请填写 Key 或切换已配置底座后保存。',
            onClose: c.closeSettings,
            onConfigured: c.markModelConfigured,
          ),
        if (c.wizardOpen && c.api != null)
          OnboardingWizard(
            api: c.api!,
            onClose: c.closeWizard,
            onCreated: c.onProfileCreated,
          ),
      ],
    );
  }

  Widget _page(AppController c) {
    final api = c.api!;
    switch (c.currentPage) {
      case AppPage.dashboard:
        return DashboardPage(api: api, onNavigate: c.setPage);
      case AppPage.chat:
        return ChatPage(controller: c);
      case AppPage.trends:
        return TrendsPage(
          api: api,
          onUseTopic: (title) {
            c.setPage(AppPage.chat);
            c.sendChat('围绕这个热点做内容：$title');
          },
        );
      case AppPage.ideas:
        return IdeasPage(api: api);
      case AppPage.calendar:
        return CalendarPage(api: api);
      case AppPage.publish:
        return PublishPage(api: api);
      case AppPage.breakdown:
        return BreakdownPage(api: api);
      case AppPage.skills:
        return SkillsPage(api: api);
      case AppPage.outputs:
        return OutputsPage(api: api);
      case AppPage.accounts:
        return AccountsPage(api: api);
      case AppPage.profile:
        return ProfilePage(
          api: api,
          onChanged: c.refreshPersonas,
          onNewProfile: c.openWizard,
        );
    }
  }
}
