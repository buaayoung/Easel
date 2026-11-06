import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class BreakdownPage extends StatefulWidget {
  const BreakdownPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<BreakdownPage> createState() => _BreakdownPageState();
}

class _BreakdownPageState extends State<BreakdownPage> {
  final _input = TextEditingController();
  bool _busy = false;
  String _result = '';
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = '';
    });
    try {
      final res = await widget.api.chat(
        message: '请拆解以下爆款内容的结构、钩子、节奏与可复用模板，用 Markdown 输出：\n\n$text',
      );
      setState(() => _result = '${res['response'] ?? res['text'] ?? res}');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _saveIdea() async {
    if (_result.isEmpty) return;
    final title = _input.text.trim().isEmpty
        ? '爆款拆解'
        : (_input.text.trim().length > 24 ? '${_input.text.trim().substring(0, 24)}…' : _input.text.trim());
    await widget.api.createIdea({
      'title': title,
      'status': 'todo',
      'note': _result,
      'source': 'breakdown',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存为选题')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '爆款拆解',
      subtitle: '粘贴爆款文案/脚本，拆出结构再入库',
      child: Column(
        children: [
          TextField(
            controller: _input,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '粘贴要拆解的爆款内容…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(onPressed: _busy ? null : _run, child: Text(_busy ? '拆解中…' : '开始拆解')),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: _result.isEmpty ? null : _saveIdea, child: const Text('存为选题')),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: EaselColors.red)),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: EaselCard(
              child: SingleChildScrollView(
                child: SelectableText(
                  _result.isEmpty ? '结果会出现在这里' : _result,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: _result.isEmpty ? EaselColors.textTertiary : EaselColors.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
