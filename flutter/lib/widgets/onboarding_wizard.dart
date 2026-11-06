import 'dart:async';

import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import 'easel_modal.dart';

const _platforms = ['小红书', '抖音', 'B站', '视频号', '公众号', '微博', '知乎', '今日头条'];
const _tones = ['专业严谨', '轻松幽默', '亲切日常', '犀利吐槽', '治愈温暖', '干货实用'];
const _steps = ['基础信息', '社媒链接', '运营意图', '偏好与红线'];

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({
    super.key,
    required this.api,
    required this.onClose,
    required this.onCreated,
  });

  final EaselApi api;
  final VoidCallback onClose;
  final ValueChanged<String> onCreated;

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  int _step = 0;
  bool _submitting = false;
  bool _enhancing = false;
  String _error = '';

  final _name = TextEditingController();
  final _direction = TextEditingController();
  final _reason = TextEditingController();
  final _goal = TextEditingController();
  final _formats = TextEditingController();
  final _likes = TextEditingController();
  final _avoid = TextEditingController();
  final _linkCtrls = <String, TextEditingController>{};

  final Set<String> _platformsSel = {};
  String _accountStage = '全新起号';
  String _tone = '';
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    _name.dispose();
    _direction.dispose();
    _reason.dispose();
    _goal.dispose();
    _formats.dispose();
    _likes.dispose();
    _avoid.dispose();
    for (final c in _linkCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _linkCtrl(String p) =>
      _linkCtrls.putIfAbsent(p, TextEditingController.new);

  bool get _canNext {
    if (_step == 0) return _name.text.trim().isNotEmpty;
    if (_step == 2) return _direction.text.trim().isNotEmpty;
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final links = <String, String>{
        for (final p in _platformsSel)
          if (_linkCtrl(p).text.trim().isNotEmpty) p: _linkCtrl(p).text.trim(),
      };
      final form = <String, dynamic>{
        'name': _name.text.trim(),
        'platforms': _platformsSel.toList(),
        'accountStage': _accountStage,
        'links': links,
        'direction': _direction.text.trim(),
        'reason': _reason.text.trim(),
        'goal': _goal.text.trim(),
        'formats': _formats.text.trim(),
        'likes': _likes.text.trim(),
        'tone': _tone,
        'avoid': _avoid.text.trim(),
      };
      final res = await widget.api.buildProfile(_name.text.trim(), form);
      if (res['created'] == true) {
        setState(() {
          _submitting = false;
          _enhancing = true;
        });
        _startPoll();
      } else {
        setState(() {
          _error = '画像创建失败，请重试';
          _submitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _submitting = false;
      });
    }
  }

  void _startPoll() {
    final name = _name.text.trim();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final st = await widget.api.profileBuildStatus(name);
        final state = '${st['state'] ?? ''}';
        if (state == 'done' || state == 'failed' || state == 'unknown') {
          _poll?.cancel();
          widget.onCreated(name);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return EaselModal(
      width: 560,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('配置账号画像',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: _submitting ? null : widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: i <= _step ? EaselColors.accentStart : EaselColors.border,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_steps[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: i == _step ? EaselColors.text : EaselColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: _body(),
              ),
            ),
            if (!_enhancing && !_submitting) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      if (_step == 0) {
                        widget.onClose();
                      } else {
                        setState(() => _step -= 1);
                      }
                    },
                    child: Text(_step == 0 ? '取消' : '上一步'),
                  ),
                  const Spacer(),
                  if (_step < _steps.length - 1)
                    FilledButton(
                      onPressed: _canNext ? () => setState(() => _step += 1) : null,
                      child: const Text('下一步'),
                    )
                  else
                    FilledButton(
                      onPressed: (_name.text.trim().isEmpty || _direction.text.trim().isEmpty)
                          ? null
                          : _submit,
                      child: const Text('生成画像'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_submitting) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在创建画像基线…', style: TextStyle(color: EaselColors.textSecondary)),
          ],
        ),
      );
    }
    if (_enhancing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('画像已创建 ✓　AI 正在后台增强…',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '正在尝试抓取社媒链接并完善各维度，可能需要 1-2 分钟。\n也可以现在就进去用，增强会在后台继续。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: EaselColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => widget.onCreated(_name.text.trim()),
              child: const Text('先进去用'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_step == 0) ...[
          _label('画像名 *（一个人设 = 一个画像，可跨多平台）'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: '如：科技数码达人'),
            onChanged: (_) => setState(() {}),
          ),
          _label('运营平台（可多选）'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _platforms)
                EaselChip(
                  label: p,
                  selected: _platformsSel.contains(p),
                  onTap: () => setState(() {
                    if (!_platformsSel.add(p)) _platformsSel.remove(p);
                  }),
                ),
            ],
          ),
          _label('起号状态'),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ['全新起号', '已有账号'])
                EaselChip(
                  label: s,
                  selected: _accountStage == s,
                  onTap: () => setState(() => _accountStage = s),
                ),
            ],
          ),
        ],
        if (_step == 1) ...[
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '贴上各平台主页链接，AI 会尽力分析你已发的内容和风格（抓不到会跳过，可留空）。',
              style: TextStyle(fontSize: 13, color: EaselColors.textSecondary),
            ),
          ),
          if (_platformsSel.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('（未选平台，可直接下一步）',
                  style: TextStyle(fontSize: 13, color: EaselColors.textSecondary)),
            ),
          for (final p in _platformsSel) ...[
            _label('$p 主页链接'),
            TextField(controller: _linkCtrl(p), decoration: const InputDecoration(hintText: 'https://…')),
          ],
        ],
        if (_step == 2) ...[
          _label('想做什么方向的内容 *（越具体越好）'),
          TextField(
            controller: _direction,
            decoration: const InputDecoration(hintText: '如：平价护肤测评'),
            onChanged: (_) => setState(() {}),
          ),
          _label('为什么做这个 / 你的优势·独特经历'),
          TextField(controller: _reason, minLines: 2, maxLines: 4),
          _label('运营目标'),
          TextField(controller: _goal, decoration: const InputDecoration(hintText: '涨粉 / 变现 / 个人品牌 / 引流私域')),
          _label('想产出的形式'),
          TextField(controller: _formats, decoration: const InputDecoration(hintText: '图文 / 短视频 / 中长视频 / 长文')),
        ],
        if (_step == 3) ...[
          _label('喜欢看的内容 / 对标账号'),
          TextField(controller: _likes, minLines: 2, maxLines: 4),
          _label('期望调性'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _tones)
                EaselChip(
                  label: t,
                  selected: _tone == t,
                  onTap: () => setState(() => _tone = _tone == t ? '' : t),
                ),
            ],
          ),
          _label('不做的内容 / 合规红线'),
          TextField(
            controller: _avoid,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '如：不接医疗功效、不做虚假宣传'),
          ),
        ],
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error, style: TextStyle(color: EaselColors.red, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 13, color: EaselColors.textSecondary)),
      );
}
