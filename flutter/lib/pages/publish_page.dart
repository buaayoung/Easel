import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

class PublishPage extends StatefulWidget {
  const PublishPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  bool _loading = true;
  String? _error;
  String _mode = 'automated';
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _platform = 'xiaohongshu';
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final policy = await widget.api.publishingPolicy();
      setState(() {
        _mode = '${policy['mode'] ?? policy['publishingMode'] ?? 'automated'}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final payload = {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'content': _body.text.trim(),
      };
      final res = _mode.contains('manual')
          ? await widget.api.exportManual(_platform, payload)
          : await widget.api.publishNow(_platform, payload);
      setState(() => _note = '已提交：${res['ok'] == true || res['status'] != null ? '成功' : res}');
    } catch (e) {
      setState(() => _note = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manual = _mode.contains('manual');
    return PageScaffold(
      title: '发布中心',
      subtitle: manual ? '人工审核 / 导出模式' : '自动适配并发布',
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  children: [
                    EaselCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: EaselColors.accentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(manual ? '人工模式' : '自动模式',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          Text('当前策略：$_mode',
                              style: const TextStyle(fontSize: 13, color: EaselColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use — controlled selection
                      value: _platform,
                      decoration: const InputDecoration(labelText: '平台'),
                      items: const [
                        DropdownMenuItem(value: 'xiaohongshu', child: Text('小红书')),
                        DropdownMenuItem(value: 'douyin', child: Text('抖音')),
                        DropdownMenuItem(value: 'weibo', child: Text('微博')),
                        DropdownMenuItem(value: 'wechat_oa', child: Text('公众号')),
                      ],
                      onChanged: (v) => setState(() => _platform = v ?? _platform),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _title, decoration: const InputDecoration(labelText: '标题')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _body,
                      minLines: 8,
                      maxLines: 16,
                      decoration: const InputDecoration(labelText: '正文', alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? '处理中…' : (manual ? '导出审核包' : '立即发布')),
                      ),
                    ),
                    if (_note != null) ...[
                      const SizedBox(height: 12),
                      Text(_note!, style: const TextStyle(color: EaselColors.textSecondary)),
                    ],
                  ],
                ),
    );
  }
}
