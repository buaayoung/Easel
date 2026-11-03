import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../api/easel_api.dart';

class _Msg {
  _Msg({required this.role, required this.text});
  final String role;
  final String text;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _messages = <_Msg>[];
  String? _sessionId;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(_Msg(role: 'user', text: text));
      _controller.clear();
    });
    try {
      _sessionId ??= const Uuid().v4().replaceAll('-', '');
      final data = await widget.api.chat(message: text, sessionId: _sessionId);
      final reply = '${data['response'] ?? ''}';
      if (data['sessionKey'] != null) {
        _sessionId = '${data['sessionKey']}';
      }
      setState(() => _messages.add(_Msg(role: 'assistant', text: reply.isEmpty ? '（空回复）' : reply)));
    } catch (e) {
      setState(() {
        _error = '$e';
        _messages.add(_Msg(role: 'assistant', text: '请求失败：$e'));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final isUser = m.role == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(m.text),
                ),
              );
            },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !_sending,
                    decoration: const InputDecoration(
                      hintText: '输入消息，调用本地 Agent…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('发送'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
