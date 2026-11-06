import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_session.dart';
import '../shell/app_controller.dart';
import '../theme/easel_theme.dart';

const _suggestions = [
  ('🔥', '蹭个热点', '看看现在微博和抖音有什么热搜，挑几个适合我做二创的选题'),
  ('✍️', '写小红书文案', '帮我写一条小红书种草文案，主题先问我'),
  ('🎴', '做金句卡片', '把一句走心的话做成一张适合发朋友圈的金句卡片'),
  ('🎬', '口播脚本', '帮我写一条 60 秒的口播短视频脚本，主题先问我'),
];

String _greeting() {
  final h = DateTime.now().hour;
  final g = h < 6
      ? '夜深了'
      : h < 12
          ? '上午好'
          : h < 14
              ? '中午好'
              : h < 18
                  ? '下午好'
                  : '晚上好';
  return '$g，想创作点什么？';
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  AppController get c => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || c.stream != null) return;
    if (preset == null) _input.clear();
    await c.sendChat(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = c.activeSession;
    final streaming = c.stream != null;
    final empty = (session?.messages.isEmpty ?? true) && !streaming;

    if (empty) return _hero();
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            children: [
              for (final m in session?.messages ?? const <ChatMessage>[]) _bubble(m),
              if (c.stream != null) ...[
                if (c.stream!.activity.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(c.stream!.activity,
                        style: const TextStyle(fontSize: 12.5, color: EaselColors.textTertiary)),
                  ),
                _bubble(ChatMessage(
                  role: 'assistant',
                  content: c.stream!.content.isEmpty ? '…' : c.stream!.content,
                  thinking: c.stream!.thinking.isEmpty ? null : c.stream!.thinking,
                )),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: _composer(hero: false),
        ),
      ],
    );
  }

  Widget _hero() {
    final direct = c.apiDirect;
    final cards = _suggestions.where((s) => !direct || s.$2 == '写小红书文案' || s.$2 == '口播脚本');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/easel-icon-transparent.png', width: 36, height: 36),
                  const SizedBox(width: 10),
                  const Text('Easel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: EaselColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 18),
              Text(_greeting(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              const SizedBox(height: 8),
              Text(
                direct ? 'API 直连：写文案、策划选题、分析附件。本机工具和自动发布未启用。' : '从选题到发布，一站式帮你把想法做成能发的内容。',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: EaselColors.textSecondary),
              ),
              const SizedBox(height: 22),
              _composer(hero: true),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in cards)
                    SizedBox(
                      width: 320,
                      child: Material(
                        color: EaselColors.surface,
                        borderRadius: BorderRadius.circular(EaselColors.radiusLg),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(EaselColors.radiusLg),
                          onTap: () => _send(s.$3),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(EaselColors.radiusLg),
                              border: Border.all(color: EaselColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.$1, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                      const SizedBox(height: 2),
                                      Text(s.$3,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: EaselColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer({required bool hero}) {
    final streaming = c.stream != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: EaselColors.bgElev,
        borderRadius: BorderRadius.circular(EaselColors.radiusXl),
        border: Border.all(color: EaselColors.border),
        boxShadow: hero ? EaselColors.shadowMd : null,
      ),
      child: Column(
        children: [
          KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (e) {
              if (e is KeyDownEvent &&
                  e.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                _send();
              }
            },
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: hero ? 2 : 1,
              maxLines: 6,
              enabled: !streaming,
              decoration: InputDecoration(
                hintText: hero
                    ? '把你的想法告诉我，选题 / 文案 / 卡片 / 视频 / 发布都行…'
                    : '发消息…（Enter 发送，Shift+Enter 换行）',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                streaming ? '生成中…' : 'Enter 发送 · Shift+Enter 换行',
                style: const TextStyle(fontSize: 11.5, color: EaselColors.textTertiary),
              ),
              const Spacer(),
              // Dark theme `.send-btn`: light fill (`--text`), dark icon (`--bg`)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: streaming ? c.stopChat : () => _send(),
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: EaselColors.text,
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Icon(
                      streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                      size: 18,
                      color: EaselColors.bg,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final user = m.role == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.62),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: user ? EaselColors.accentSoft : EaselColors.surface,
          borderRadius: BorderRadius.circular(EaselColors.radiusLg),
          border: Border.all(color: EaselColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((m.thinking ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EaselColors.accentSoft,
                  borderRadius: BorderRadius.circular(EaselColors.radius),
                ),
                child: Text(m.thinking!,
                    style: const TextStyle(fontSize: 12.5, color: EaselColors.textSecondary)),
              ),
            SelectableText(m.content, style: const TextStyle(fontSize: 14, height: 1.55)),
          ],
        ),
      ),
    );
  }
}
