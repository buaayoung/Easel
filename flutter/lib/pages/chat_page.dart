import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/easel_api.dart';
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
  late final FocusNode _focus = FocusNode(onKeyEvent: _onFocusKey);

  final List<UploadedFile> _attachments = [];
  bool _uploading = false;
  bool _dragOver = false;
  int _maxMb = 50;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onController);
    c.streamListenable.addListener(_onStreamTick);
    _loadLimits();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  void _onStreamTick() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLimits() async {
    final api = c.api;
    if (api == null) return;
    try {
      final mb = await api.uploadMaxMb();
      if (mounted) setState(() => _maxMb = mb);
    } catch (_) {}
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    c.streamListenable.removeListener(_onStreamTick);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onFocusKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final meta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (meta && event.logicalKey == LogicalKeyboardKey.keyV) {
      _pasteFiles();
      // Still allow text paste into the field.
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    final atts = List<UploadedFile>.of(_attachments);
    if ((text.isEmpty && atts.isEmpty) || c.stream != null || _uploading)
      return;
    if (preset == null) {
      _input.clear();
      setState(() => _attachments.clear());
    }
    await c.sendChat(
      text,
      attachments: [
        for (final a in atts)
          ChatAttachment(id: a.id, name: a.name, path: a.path),
      ],
    );
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

  Future<void> _pickFiles() async {
    if (c.stream != null || _uploading) return;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.paths.isEmpty) return;
    final paths = result.paths.whereType<String>().toList();
    await _uploadPaths(paths);
  }

  Future<void> _pasteFiles() async {
    if (c.stream != null || _uploading) return;
    try {
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        await _uploadPaths(files);
        return;
      }
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, 'paste-${DateTime.now().millisecondsSinceEpoch}.png'),
      );
      await file.writeAsBytes(bytes, flush: true);
      await _uploadPaths([file.path]);
    } catch (_) {
      /* clipboard may have text only */
    }
  }

  Future<void> _uploadPaths(List<String> paths) async {
    final api = c.api;
    final session = c.activeSession;
    if (api == null || session == null || paths.isEmpty) return;

    final cap = _maxMb * 1024 * 1024;
    final big = <String>[];
    final small = <String>[];
    for (final path in paths) {
      try {
        final size = await File(path).length();
        if (size > cap) {
          big.add(path);
        } else {
          small.add(path);
        }
      } catch (_) {
        small.add(path);
      }
    }

    setState(() => _uploading = true);
    try {
      if (big.isNotEmpty) {
        final saved = await api.uploadFiles(big, session.id, local: true);
        if (mounted) setState(() => _attachments.addAll(saved));
      }
      if (small.isNotEmpty) {
        final saved = await api.uploadFiles(small, session.id);
        if (mounted) setState(() => _attachments.addAll(saved));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeAttachment(String path) {
    setState(() => _attachments.removeWhere((a) => a.path == path));
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
              for (final m in session?.messages ?? const <ChatMessage>[])
                _bubble(m),
              if (c.stream != null) ...[
                if (c.stream!.activity.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      c.stream!.activity,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: EaselColors.textTertiary,
                      ),
                    ),
                  ),
                _bubble(
                  ChatMessage(
                    role: 'assistant',
                    content: c.stream!.content.isEmpty
                        ? '…'
                        : c.stream!.content,
                    thinking: c.stream!.thinking.isEmpty
                        ? null
                        : c.stream!.thinking,
                  ),
                ),
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
    final cards = _suggestions.where(
      (s) => !direct || s.$2 == '写小红书文案' || s.$2 == '口播脚本',
    );
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
                  Image.asset(
                    'assets/unisyn-icon-transparent.png',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Unisyn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: EaselColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _greeting(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                direct
                    ? 'API 直连：写文案、策划选题、分析附件。本机工具和自动发布未启用。'
                    : '从选题到发布，一站式帮你把想法做成能发的内容。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: EaselColors.textSecondary,
                ),
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
                        borderRadius: BorderRadius.circular(
                          EaselColors.radiusLg,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            EaselColors.radiusLg,
                          ),
                          onTap: () => _send(s.$3),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                EaselColors.radiusLg,
                              ),
                              border: Border.all(color: EaselColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.$1,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.$2,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s.$3,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: EaselColors.textSecondary,
                                        ),
                                      ),
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
    final canSend =
        (_input.text.trim().isNotEmpty || _attachments.isNotEmpty) &&
        !streaming &&
        !_uploading;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: (detail) async {
        setState(() => _dragOver = false);
        final paths = detail.files
            .map((f) => f.path)
            .where((p) => p.isNotEmpty)
            .toList();
        if (paths.isNotEmpty) await _uploadPaths(paths);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: _dragOver ? EaselColors.accentSoft : EaselColors.bgElev,
          borderRadius: BorderRadius.circular(EaselColors.radiusXl),
          border: Border.all(
            color: _dragOver ? EaselColors.accentStart : EaselColors.border,
            width: _dragOver ? 1.5 : 1,
          ),
          boxShadow: _dragOver
              ? [
                  BoxShadow(
                    color: EaselColors.accentStart.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : (hero ? EaselColors.shadowMd : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_attachments.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final a in _attachments) _attachChip(a)],
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _input,
              focusNode: _focus,
              minLines: hero ? 2 : 1,
              maxLines: 6,
              enabled: !streaming,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _dragOver
                    ? '松手上传素材…'
                    : hero
                    ? '把你的想法告诉我，选题 / 文案 / 卡片 / 视频 / 发布都行…（可拖入图片/文档当素材）'
                    : '发消息…（Enter 发送，Shift+Enter 换行，可拖入/粘贴素材）',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Tooltip(
                  message: '添加素材（图片/文档）；超过 ${_maxMb}MB 的大文件将自动存为本地素材（不走上传）',
                  child: OutlinedButton.icon(
                    onPressed: streaming || _uploading ? null : _pickFiles,
                    icon: Icon(
                      Icons.add,
                      size: 15,
                      color: streaming || _uploading
                          ? EaselColors.textTertiary
                          : EaselColors.textSecondary,
                    ),
                    label: Text(
                      _uploading ? '上传中…' : '素材',
                      style: TextStyle(
                        fontSize: 12,
                        color: streaming || _uploading
                            ? EaselColors.textTertiary
                            : EaselColors.textSecondary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      minimumSize: const Size(0, 28),
                      side: BorderSide(color: EaselColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      backgroundColor: Colors.transparent,
                      foregroundColor: EaselColors.textSecondary,
                      disabledForegroundColor: EaselColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    streaming ? '生成中…' : 'Enter 发送 · Shift+Enter 换行',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: EaselColors.textTertiary,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: streaming
                        ? c.stopChat
                        : (canSend ? () => _send() : null),
                    borderRadius: BorderRadius.circular(10),
                    child: Opacity(
                      opacity: streaming || canSend ? 1 : 0.35,
                      child: Ink(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: EaselColors.text,
                          boxShadow: [
                            BoxShadow(
                              color: EaselColors.isDark
                                  ? const Color(0x33000000)
                                  : const Color(0x2E17191C),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          streaming
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          size: 18,
                          color: EaselColors.isDark
                              ? EaselColors.bg
                              : Colors.white,
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
    );
  }

  Widget _attachChip(UploadedFile a) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: EaselColors.surfaceHover,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: EaselColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 12,
            color: EaselColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              a.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: EaselColors.textSecondary),
            ),
          ),
          InkWell(
            onTap: () => _removeAttachment(a.path),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '×',
                style: TextStyle(
                  fontSize: 15,
                  height: 1,
                  color: EaselColors.textTertiary,
                ),
              ),
            ),
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.62,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: user
            ? BoxDecoration(
                gradient: EaselColors.isDark
                    ? null
                    : EaselColors.accentGradientSoft,
                color: EaselColors.isDark ? EaselColors.accentSoft : null,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(EaselColors.radiusLg),
                  topRight: Radius.circular(EaselColors.radiusLg),
                  bottomLeft: Radius.circular(EaselColors.radiusLg),
                  bottomRight: const Radius.circular(4),
                ),
                border: Border.all(
                  color: EaselColors.isDark
                      ? EaselColors.border
                      : const Color(0x14334294),
                ),
                boxShadow: EaselColors.isDark
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x0E17191C),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
              )
            : null,
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
                child: Text(
                  m.thinking!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: EaselColors.textSecondary,
                  ),
                ),
              ),
            if (m.content.isNotEmpty)
              SelectableText(
                m.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: user && !EaselColors.isDark
                      ? const Color(0xFF303238)
                      : EaselColors.text,
                ),
              )
            else if ((m.attachments ?? const []).isNotEmpty)
              Text(
                '已附 ${(m.attachments ?? const []).map((a) => a.name).join('、')}',
                style: TextStyle(
                  fontSize: 13,
                  color: EaselColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
