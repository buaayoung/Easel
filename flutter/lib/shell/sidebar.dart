import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../theme/easel_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/theme_toggle.dart';
import 'app_controller.dart';

const _nav = <(AppPage, IconData, String)>[
  (AppPage.dashboard, Icons.grid_view_rounded, '工作台'),
  (AppPage.chat, Icons.chat_bubble_outline, '对话'),
  (AppPage.skills, Icons.auto_awesome_outlined, '技能库'),
  (AppPage.outputs, Icons.folder_outlined, '内容库'),
  (AppPage.accounts, Icons.person_outline, '账号'),
  (AppPage.profile, Icons.badge_outlined, '画像'),
];

class EaselSidebar extends StatefulWidget {
  const EaselSidebar({super.key, required this.controller, required this.theme});

  final AppController controller;
  final ThemeController theme;

  @override
  State<EaselSidebar> createState() => _EaselSidebarState();
}

class _EaselSidebarState extends State<EaselSidebar> {
  String? _renamingId;
  final _renameCtrl = TextEditingController();
  bool _showArchived = false;

  AppController get c => widget.controller;

  @override
  void dispose() {
    _renameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = c.sessions
        .where(
          (s) =>
              !s.archived &&
              (s.messages.isNotEmpty || s.id == c.activeSessionId),
        )
        .toList();
    final archived = c.sessions.where((s) => s.archived).toList();

    return Container(
      width: EaselColors.sidebarWidth,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EaselColors.sidebarTop,
            EaselColors.sidebarMid,
            EaselColors.sidebarBottom,
          ],
          stops: const [0, 0.72, 1],
        ),
        border: Border(right: BorderSide(color: EaselColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/easel-icon-transparent.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Unisyn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: EaselColors.text,
                      ),
                    ),
                    const Spacer(),
                    ThemeToggleButton(controller: widget.theme),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (_) {
                    final names = c.personas
                        .map((p) => '${p['name'] ?? ''}')
                        .where((n) => n.isNotEmpty)
                        .toSet();
                    final current =
                        names.contains(c.selectedPersona) ||
                            c.selectedPersona.isEmpty
                        ? c.selectedPersona
                        : '';
                    return DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use — need controlled value when persona list changes
                      value: current,
                      dropdownColor: EaselColors.bgElev,
                      style: TextStyle(
                        color: EaselColors.text,
                        fontSize: 13.5,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('通用模式')),
                        ...names.map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        ),
                        const DropdownMenuItem(
                          value: '__new__',
                          child: Text('+ 新建画像…'),
                        ),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        if (v == '__new__') {
                          c.openWizard();
                          return;
                        }
                        await c.selectPersona(v);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Column(
              children: [
                for (final (page, icon, label) in _nav)
                  _NavItem(
                    icon: icon,
                    label: label,
                    active:
                        c.currentPage == page ||
                        (page == AppPage.dashboard &&
                            {
                              AppPage.trends,
                              AppPage.ideas,
                              AppPage.calendar,
                              AppPage.publish,
                              AppPage.breakdown,
                            }.contains(c.currentPage)),
                    onTap: () => c.setPage(page),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          '对话',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: EaselColors.textTertiary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: c.newChat,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          '新对话',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: EaselColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final s in active) _sessionTile(s, false),
                        if (archived.isNotEmpty) ...[
                          InkWell(
                            onTap: () =>
                                setState(() => _showArchived = !_showArchived),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                              child: Row(
                                children: [
                                  Icon(
                                    _showArchived
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    size: 14,
                                    color: EaselColors.textTertiary,
                                  ),
                                  Text(
                                    '已归档 · ${archived.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: EaselColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showArchived)
                            for (final s in archived) _sessionTile(s, true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: EaselColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.gatewayStatus == 'connected'
                        ? EaselColors.green
                        : EaselColors.red,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (c.gatewayStatus == 'connected'
                                    ? EaselColors.green
                                    : EaselColors.red)
                                .withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusText(),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: EaselColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: c.openSettings,
                  icon: Badge(
                    isLabelVisible: !c.modelConfigured,
                    smallSize: 8,
                    child: const Icon(Icons.settings_outlined, size: 14),
                  ),
                  label: const Text('设置', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: EaselColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    if (c.gatewayStatus == 'connected') {
      if (c.apiDirect) return '仅聊天模式已配置';
      if (c.agentRuntime != 'openclaw') return '${c.agentRuntime} CLI 已安装';
      return '网关已连接';
    }
    if (c.gatewayStatus == 'disconnected') {
      if (c.apiDirect) return 'API 配置不完整';
      if (c.agentRuntime != 'openclaw') return '${c.agentRuntime} CLI 未配置';
      return '网关离线';
    }
    return '连接中…';
  }

  Widget _sessionTile(ChatSession s, bool isArchived) {
    if (_renamingId == s.id) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: TextField(
          controller: _renameCtrl,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          onSubmitted: (v) async {
            await c.renameSession(s.id, v);
            setState(() => _renamingId = null);
          },
          onTapOutside: (_) async {
            await c.renameSession(s.id, _renameCtrl.text);
            setState(() => _renamingId = null);
          },
        ),
      );
    }
    final selected = s.id == c.activeSessionId;
    return Material(
      color: selected ? EaselColors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(EaselColors.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        onTap: () => c.selectSession(s.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected
                        ? EaselColors.text
                        : EaselColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              _iconBtn(Icons.edit_outlined, () {
                setState(() {
                  _renamingId = s.id;
                  _renameCtrl.text = s.title;
                });
              }),
              _iconBtn(
                isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                () => c.archiveSession(s.id, !isArchived),
              ),
              _iconBtn(
                Icons.delete_outline,
                () => c.deleteSession(s.id),
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 14,
          color: danger ? EaselColors.red : EaselColors.textTertiary,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? EaselColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(EaselColors.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(EaselColors.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                if (active) ...[
                  navActiveStripe(height: 16),
                  const SizedBox(width: 8),
                ] else
                  const SizedBox(width: 11),
                Icon(
                  icon,
                  size: 18,
                  color: active ? EaselColors.text : EaselColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active
                        ? EaselColors.text
                        : EaselColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
