import 'dart:async';

import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/easel_modal.dart';
import '../widgets/page_scaffold.dart';

const _stateLabel = <String, String>{
  'starting': '启动中…',
  'qr_ready': '请扫码',
  'scanned': '扫码成功',
  'sms_required': '需短信验证',
  'verifying': '验证中…',
  'window_login': '请在浏览器窗口登录',
  'success': '登录成功',
  'expired': '二维码已过期',
  'error': '登录出错',
  'unknown': '等待中…',
};

class _QrState {
  _QrState({
    required this.platform,
    required this.name,
    required this.state,
    this.message = '',
    this.qr = '',
    this.qrTs,
  });

  final String platform;
  final String name;
  String state;
  String message;
  String qr;
  int? qrTs;
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _accounts = [];
  String? _busy;
  String? _logoutBusy;
  String? _terminalMsg;

  _QrState? _qr;
  Timer? _poll;
  int _qrSeq = 0;
  int _qrNonce = 0;
  final _smsCtrl = TextEditingController();
  String _smsErr = '';
  bool _smsBusy = false;

  Map<String, dynamic>? _cred; // {platform, name}
  final _appId = TextEditingController();
  final _appSecret = TextEditingController();
  final _author = TextEditingController();
  bool _credBusy = false;
  String _credMsg = '';
  String _credErr = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _smsCtrl.dispose();
    _appId.dispose();
    _appSecret.dispose();
    _author.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await widget.api.accounts();
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  void _closeQr() {
    _qrSeq += 1;
    _stopPoll();
    setState(() {
      _qr = null;
      _smsCtrl.clear();
      _smsErr = '';
    });
  }

  Future<void> _openCred(Map<String, dynamic> a) async {
    final platform = '${a['platform'] ?? ''}';
    setState(() {
      _cred = {'platform': platform, 'name': '${a['name'] ?? platform}'};
      _credMsg = '';
      _credErr = '';
      _appId.clear();
      _appSecret.clear();
      _author.clear();
    });
    try {
      final c = await widget.api.getCredentials(platform);
      if (!mounted || _cred == null) return;
      setState(() {
        _appId.text = '${c['appIdMasked'] ?? ''}'.replaceAll('*', '');
        _author.text = '${c['author'] ?? ''}';
        if (c['configured'] == true) {
          _credMsg = '已配置 AppID：${c['appIdMasked'] ?? ''}（Secret 不回显，重填才更新）';
        }
      });
    } catch (_) {}
  }

  void _closeCred() {
    setState(() {
      _cred = null;
      _credBusy = false;
      _credMsg = '';
      _credErr = '';
    });
  }

  Future<void> _submitCred() async {
    final cred = _cred;
    if (cred == null) return;
    final appId = _appId.text.trim();
    final secret = _appSecret.text.trim();
    if (appId.isEmpty || secret.isEmpty) {
      setState(() => _credErr = '请填写 AppID 与 AppSecret');
      return;
    }
    setState(() {
      _credBusy = true;
      _credErr = '';
      _credMsg = '';
    });
    try {
      final r = await widget.api.saveCredentials(
        '${cred['platform']}',
        appId: appId,
        appSecret: secret,
        name: '${cred['name']}',
        author: _author.text.trim(),
      );
      setState(() => _credMsg = '${r['message'] ?? '已保存并验证'}');
      await _load();
    } catch (e) {
      setState(() => _credErr = '$e');
    } finally {
      setState(() => _credBusy = false);
    }
  }

  Future<void> _login(Map<String, dynamic> a) async {
    final platform = '${a['platform'] ?? ''}';
    final name = '${a['name'] ?? platform}';
    final backend = '${a['backend'] ?? ''}';
    final supported = a['supported'] != false;
    if (!supported) return;

    if (backend == 'wechat-oa') {
      await _mpLogin(a);
      return;
    }

    final seq = ++_qrSeq;
    _stopPoll();
    setState(() {
      _busy = platform;
      _terminalMsg = null;
      _smsCtrl.clear();
      _smsErr = '';
      _qrNonce += 1;
      _qr = _QrState(
        platform: platform,
        name: name,
        state: 'starting',
        message: '正在启动浏览器并准备二维码…',
      );
    });

    try {
      final res = await widget.api.startLogin(platform);
      if (!mounted || seq != _qrSeq) return;
      final mode = '${res['mode'] ?? ''}';
      if (mode == 'terminal') {
        setState(() {
          _qr = null;
          _terminalMsg = '${res['message'] ?? '请在终端登录'}';
        });
        return;
      }
      if (mode == 'credentials') {
        setState(() => _qr = null);
        await _openCred(a);
        return;
      }
      setState(() {
        _qr = _QrState(
          platform: platform,
          name: name,
          state: '${res['state'] ?? 'starting'}',
          message: '${res['message'] ?? ''}',
          qr: '${res['qr'] ?? ''}',
          qrTs: (res['qrTs'] as num?)?.toInt(),
        );
      });
      _startPoll(platform, seq, useMp: false);
    } catch (e) {
      if (!mounted || seq != _qrSeq) return;
      setState(() {
        _qr?.state = 'error';
        _qr?.message = '$e';
      });
    } finally {
      if (mounted && seq == _qrSeq) setState(() => _busy = null);
    }
  }

  Future<void> _mpLogin(Map<String, dynamic> a) async {
    final platform = '${a['platform'] ?? ''}';
    final name = '${a['name'] ?? platform}';
    final seq = ++_qrSeq;
    _stopPoll();
    setState(() {
      _busy = '$platform:mp';
      _smsCtrl.clear();
      _smsErr = '';
      _qrNonce += 1;
      _qr = _QrState(
        platform: platform,
        name: '$name · 后台取数',
        state: 'starting',
        message: '正在启动浏览器并准备二维码…',
      );
    });
    try {
      final res = await widget.api.startMpLogin(platform);
      if (!mounted || seq != _qrSeq) return;
      setState(() {
        _qr = _QrState(
          platform: platform,
          name: '$name · 后台取数',
          state: '${res['state'] ?? 'starting'}',
          message: '${res['message'] ?? ''}',
          qr: '${res['qr'] ?? ''}',
          qrTs: (res['qrTs'] as num?)?.toInt(),
        );
      });
      _startPoll(platform, seq, useMp: true);
    } catch (e) {
      if (!mounted || seq != _qrSeq) return;
      setState(() {
        _qr?.state = 'error';
        _qr?.message = '$e';
      });
    } finally {
      if (mounted && seq == _qrSeq) setState(() => _busy = null);
    }
  }

  void _startPoll(String platform, int seq, {required bool useMp}) {
    _stopPoll();
    final started = DateTime.now();
    var failures = 0;
    var polling = false;
    _poll = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || seq != _qrSeq || polling) return;
      if (DateTime.now().difference(started) > const Duration(minutes: 6)) {
        _stopPoll();
        setState(() {
          _qr?.state = 'expired';
          _qr?.message = '登录等待超时，请关闭后重新登录';
          _qr?.qr = '';
        });
        return;
      }
      polling = true;
      try {
        final s = useMp
            ? await widget.api.mpLoginStatus(platform)
            : await widget.api.loginStatus(platform);
        if (!mounted || seq != _qrSeq) return;
        failures = 0;
        setState(() {
          _qr?.state = '${s['state'] ?? _qr?.state}';
          _qr?.message = '${s['message'] ?? ''}';
          _qr?.qr = '${s['qr'] ?? _qr?.qr ?? ''}';
          _qr?.qrTs = (s['qrTs'] as num?)?.toInt() ?? _qr?.qrTs;
        });
        final state = '${s['state'] ?? ''}';
        if (state == 'success' || state == 'expired' || state == 'error') {
          _stopPoll();
          if (state == 'success') await _load();
        }
      } catch (_) {
        failures += 1;
        if (failures >= 5) {
          _stopPoll();
          setState(() {
            _qr?.state = 'error';
            _qr?.message = '登录状态连接中断，请检查网络后重新登录';
            _qr?.qr = '';
          });
        }
      } finally {
        polling = false;
      }
    });
  }

  Future<void> _submitSms() async {
    final qr = _qr;
    if (qr == null) return;
    final code = _smsCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _smsErr = '请输入验证码');
      return;
    }
    setState(() {
      _smsBusy = true;
      _smsErr = '';
      qr.state = 'verifying';
      qr.message = '正在验证验证码…';
    });
    try {
      await widget.api.submitLoginSms(qr.platform, code);
    } catch (e) {
      setState(() {
        _smsErr = '$e';
        qr.state = 'sms_required';
      });
    } finally {
      setState(() => _smsBusy = false);
    }
  }

  Future<void> _logout(String platform) async {
    setState(() => _logoutBusy = platform);
    try {
      await widget.api.logoutAccount(platform);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _logoutBusy = null);
    }
  }

  Future<void> _whoami(String platform) async {
    try {
      final info = await widget.api.accountWhoami(platform, force: true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(platform),
          content: SelectableText('$info'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageScaffold(
          title: '账号',
          subtitle: '平台登录、二维码与会话状态',
          actions: [
            if (_accounts.any((a) => '${a['backend']}' == 'wechat-oa'))
              TextButton(
                onPressed: () {
                  final a = _accounts.firstWhere(
                    (e) => '${e['backend']}' == 'wechat-oa',
                    orElse: () => {'platform': 'wechat_oa', 'name': '公众号'},
                  );
                  _openCred(a);
                },
                child: const Text('配置公众号凭证'),
              ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : Column(
                      children: [
                        if (_terminalMsg != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: EaselColors.surface2,
                              borderRadius: BorderRadius.circular(EaselColors.radius),
                              border: Border.all(color: EaselColors.border),
                            ),
                            child: Text(_terminalMsg!, style: const TextStyle(fontSize: 13)),
                          ),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 320,
                              mainAxisExtent: 168,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _accounts.isEmpty ? 0 : _accounts.length,
                            itemBuilder: (_, i) {
                              final item = _accounts[i];
                              final platform = '${item['platform'] ?? item['id'] ?? item['name'] ?? ''}';
                              final name = '${item['name'] ?? platform}';
                              final logged = item['loggedIn'] == true ||
                                  item['ok'] == true ||
                                  '${item['status']}'.contains('ok') ||
                                  '${item['status']}'.contains('logged');
                              final supported = item['supported'] != false;
                              final backend = '${item['backend'] ?? ''}';
                              final busy = _busy == platform || _busy == '$platform:mp';
                              return Opacity(
                                opacity: supported ? 1 : 0.6,
                                child: EaselCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      const SizedBox(height: 6),
                                      Text(
                                        logged ? '已登录' : (item['note']?.toString().isNotEmpty == true
                                            ? '${item['note']}'
                                            : '未登录'),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: logged ? EaselColors.green : EaselColors.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (logged)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton.tonal(
                                                onPressed: busy ? null : () => _whoami(platform),
                                                child: const Text('校验账号'),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: TextButton(
                                                onPressed: _logoutBusy == platform
                                                    ? null
                                                    : () => _logout(platform),
                                                child: Text(_logoutBusy == platform ? '…' : '退出'),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: (!supported || busy) ? null : () => _login(item),
                                                child: Text(busy ? '启动中…' : '登录'),
                                              ),
                                            ),
                                            if (backend == 'wechat-oa') ...[
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: '配置 AppID / AppSecret',
                                                onPressed: () => _openCred(item),
                                                icon: const Icon(Icons.key_outlined, size: 18),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_accounts.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text('暂无账号平台数据', style: TextStyle(color: EaselColors.textSecondary)),
                            ),
                          ),
                      ],
                    ),
        ),
        if (_qr != null) _qrModal(_qr!),
        if (_cred != null) _credModal(),
      ],
    );
  }

  Widget _qrModal(_QrState qr) {
    final stateColor = qr.state == 'success'
        ? EaselColors.green
        : (qr.state == 'error' || qr.state == 'expired')
            ? EaselColors.red
            : EaselColors.textSecondary;
    final label = (qr.state == 'expired' && qr.qr.isEmpty)
        ? '登录超时/未完成'
        : (_stateLabel[qr.state] ?? qr.state);

    return EaselModal(
      width: 360,
      onBarrierTap: _closeQr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('登录 ${qr.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              qr.message.isEmpty ? label : '$label — ${qr.message}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: stateColor, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (qr.state == 'sms_required') ...[
              TextField(
                controller: _smsCtrl,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20, letterSpacing: 6),
                decoration: const InputDecoration(hintText: '短信验证码'),
                onSubmitted: (_) => _submitSms(),
              ),
              if (_smsErr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_smsErr, style: const TextStyle(color: EaselColors.red, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _smsBusy ? null : _submitSms,
                  child: Text(_smsBusy ? '提交中…' : '提交验证码'),
                ),
              ),
            ] else if (qr.state == 'qr_ready' && qr.qr.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(EaselColors.radius),
                child: Image.network(
                  '${widget.api.mediaUrl(qr.qr)}?v=${qr.qrTs ?? _qrNonce}',
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 240,
                    child: Center(child: Text('二维码加载失败', style: TextStyle(color: EaselColors.red))),
                  ),
                ),
              ),
            ] else if (qr.state == 'success') ...[
              const Padding(
                padding: EdgeInsets.all(40),
                child: Icon(Icons.check_circle, size: 56, color: EaselColors.green),
              ),
            ] else if (qr.state == 'error' || qr.state == 'expired') ...[
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  qr.message.isEmpty ? '登录失败，可关闭后重试' : qr.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: EaselColors.red, fontSize: 13),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('准备中…', style: TextStyle(color: EaselColors.textSecondary)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _closeQr,
              child: Text(qr.state == 'success' ? '完成' : '关闭'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credModal() {
    final name = '${_cred?['name'] ?? ''}';
    return EaselModal(
      width: 420,
      onBarrierTap: _closeCred,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('配置 $name', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              '公众号用官方接口发布，需填开发者凭证（公众平台 → 设置与开发 → 开发接口管理）。\n'
              '需把本机出口 IP 加入公众号「IP 白名单」，否则报 40164。文章发到草稿箱。',
              style: TextStyle(fontSize: 12.5, color: EaselColors.textSecondary, height: 1.55),
            ),
            if (_credMsg.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_credMsg, style: const TextStyle(color: EaselColors.green, fontSize: 12.5)),
            ],
            const SizedBox(height: 12),
            const Text('AppID', style: TextStyle(fontSize: 12, color: EaselColors.textSecondary)),
            TextField(controller: _appId, autofocus: true, decoration: const InputDecoration(hintText: 'wx...')),
            const SizedBox(height: 10),
            const Text('AppSecret', style: TextStyle(fontSize: 12, color: EaselColors.textSecondary)),
            TextField(
              controller: _appSecret,
              obscureText: true,
              decoration: const InputDecoration(hintText: '开发者密钥（不会回显）'),
            ),
            const SizedBox(height: 10),
            const Text('默认作者（可选）', style: TextStyle(fontSize: 12, color: EaselColors.textSecondary)),
            TextField(controller: _author, decoration: const InputDecoration(hintText: '文章署名')),
            if (_credErr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_credErr, style: const TextStyle(color: EaselColors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _credBusy ? null : _submitCred,
                    child: Text(_credBusy ? '验证中…' : '保存并验证'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: _closeCred, child: const Text('关闭')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
