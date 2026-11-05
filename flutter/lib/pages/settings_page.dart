import 'package:flutter/material.dart';

import '../api/easel_api.dart';
import 'env_page.dart';

/// Mirrors web `SettingsPanel` + `HarnessSettings` for OpenClaw / API config.
const _channels = <(String, String)>[
  ('chat', '对话与脚本'),
  ('transcribe', '语音转写'),
  ('speech', '配音'),
  ('image', '生图'),
  ('video', '视频'),
  ('music', '音乐'),
];

const _slotEdit = <String, ({bool model, bool base})>{
  'direct-api': (model: true, base: true),
  'openai': (model: true, base: true),
  'relay': (model: true, base: true),
  'anthropic': (model: true, base: true),
  'siliconflow': (model: false, base: true),
  'custom': (model: true, base: true),
};

const _thinkingFormats = <(String, String)>[
  ('', '保留现有 / 自动'),
  ('openai', 'OpenAI'),
  ('deepseek', 'DeepSeek'),
  ('openrouter', 'OpenRouter'),
  ('together', 'Together'),
  ('qwen', 'Qwen'),
  ('qwen-chat-template', 'Qwen chat template'),
  ('zai', 'ZAI'),
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.api,
    this.banner,
    this.onConfigured,
  });

  final EaselApi api;
  final String? banner;
  final VoidCallback? onConfigured;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _sec = 0; // 0 模型配置 1 环境安装 2 更多设置
  String _chan = 'chat';

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _error;
  String? _note;

  // Harness: saved vs preview (same as web)
  String _harness = '';
  String _selectedHarness = '';
  bool _locked = false;
  List<Map<String, dynamic>> _agents = [];
  final _nativeModel = TextEditingController();
  String _sandbox = 'workspace-write';
  bool _codexAuto = false;

  // Channel rows keyed by channel id — mutable maps like web ModelRow + keyNew
  final Map<String, List<Map<String, dynamic>>> _channelRows = {
    for (final (id, _) in _channels) id: <Map<String, dynamic>>[],
  };
  Map<String, dynamic>? _selftestByBase; // baseUrl -> result
  int? _selftestAt;

  // Local agents (openclaw only when saved harness is openclaw)
  List<Map<String, dynamic>> _localAgents = [];
  String? _localAgentsErr;
  String _enabling = '';
  final Map<String, String> _laModels = {};
  String? _localAgentNote;

  final _proxyCtrl = TextEditingController();
  String _proxySource = 'none';
  bool _proxyBusy = false;
  Map<String, dynamic>? _bootstrap;

  // Controllers for editable fields per channel#index
  final Map<String, TextEditingController> _ctrls = {};

  bool get _previewMismatch =>
      _selectedHarness.isNotEmpty &&
      _harness.isNotEmpty &&
      _selectedHarness != _harness;

  bool get _apiPanelVisible =>
      _chan == 'chat' &&
      (_selectedHarness == 'api' || _selectedHarness == 'openclaw');

  bool get _chatOk {
    final rows = _channelRows['chat'] ?? [];
    if (rows.isEmpty) return false;
    final result = '${rows.first['result'] ?? ''}';
    return result.isNotEmpty && !result.contains('缺');
  }

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  @override
  void dispose() {
    _nativeModel.dispose();
    _proxyCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _cKey(String field, int i) => '$_chan#$i#$field';

  TextEditingController _ctrl(String field, int i, String initial) {
    final k = _cKey(field, i);
    final existing = _ctrls[k];
    if (existing != null) return existing;
    final c = TextEditingController(text: initial);
    _ctrls[k] = c;
    return c;
  }

  void _clearChannelCtrls(String chan) {
    final prefix = '$chan#';
    final keys = _ctrls.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      _ctrls.remove(k)?.dispose();
    }
  }

  String _clean(String? v) {
    final s = (v ?? '').trim();
    return modelPlaceholders.contains(s) ? '' : s;
  }

  Future<void> _reloadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final boot = await widget.api.bootstrap();
      final harness = await widget.api.harness();
      _applyHarness(harness, selectToo: true);
      await _loadModelsForSelected();
      final proxy = await widget.api.proxy();
      _proxyCtrl.text = '${proxy['proxy'] ?? ''}';
      _proxySource = '${proxy['source'] ?? 'none'}';
      if (_harness == 'openclaw') await _loadLocalAgents();
      setState(() {
        _bootstrap = boot;
        _loading = false;
      });
      if (boot['modelConfigured'] == true) widget.onConfigured?.call();
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _applyHarness(Map<String, dynamic> harness, {bool selectToo = false}) {
    _harness = '${harness['runtime'] ?? 'openclaw'}';
    if (selectToo || _selectedHarness.isEmpty) _selectedHarness = _harness;
    _locked = harness['locked'] == true;
    _sandbox = '${harness['sandbox'] ?? 'workspace-write'}';
    _codexAuto = harness['codex_auto_approve'] == true;
    final models = harness['models'];
    if (models is Map) {
      _nativeModel.text = '${models[_selectedHarness] ?? ''}';
    }
    _agents = (harness['agents'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _loadModelsForSelected() async {
    final runtime =
        (_selectedHarness == 'api' || _selectedHarness == 'openclaw')
            ? _selectedHarness
            : null;
    final data = await widget.api.models(runtime: runtime);
    _ingestModels(data);
  }

  void _ingestModels(Map<String, dynamic> data) {
    final channels = data['channels'];
    if (channels is! Map) return;
    for (final (id, _) in _channels) {
      _clearChannelCtrls(id);
      final block = channels[id];
      final rows = block is Map ? block['rows'] : null;
      _channelRows[id] = (rows as List? ?? [])
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            m['keyNew'] = '';
            m['model'] = _clean('${m['model']}');
            m['baseUrl'] = _clean('${m['baseUrl']}');
            return m;
          })
          .toList();
    }
  }

  Future<void> _loadLocalAgents() async {
    try {
      final d = await widget.api.localAgents();
      setState(() {
        _localAgents = (d['agents'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((a) => a['installed'] == true)
            .toList();
        _localAgentsErr = null;
      });
    } catch (e) {
      setState(() => _localAgentsErr = '$e');
    }
  }

  Future<void> _saveHarness() async {
    setState(() {
      _saving = true;
      _error = null;
      _note = null;
    });
    try {
      final data = await widget.api.saveHarness(
        runtime: _selectedHarness,
        model: _nativeModel.text.trim(),
        sandbox: _sandbox,
        codexAutoApprove: _selectedHarness == 'codex' ? _codexAuto : null,
      );
      _applyHarness(data, selectToo: true);
      await _loadModelsForSelected();
      if (_harness == 'openclaw') await _loadLocalAgents();
      setState(() {
        _note = '已保存，请新建对话；旧对话仍保留在原底座，不迁移历史。';
        _saving = false;
      });
      final boot = await widget.api.bootstrap();
      setState(() => _bootstrap = boot);
      if (boot['modelConfigured'] == true) widget.onConfigured?.call();
    } catch (e) {
      setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  Future<void> _rereadHarness() async {
    try {
      final data = await widget.api.harness();
      setState(() => _applyHarness(data, selectToo: true));
      await _loadModelsForSelected();
      setState(() => _note = '已重新读取底座');
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  List<Map<String, dynamic>> get _currentRows =>
      _channelRows[_chan] ?? <Map<String, dynamic>>[];

  Future<void> _saveConfig() async {
    if (_chan == 'chat' &&
        _selectedHarness != 'api' &&
        _selectedHarness != 'openclaw') {
      setState(() => _error = '请使用下方「保存底座」保存原生配置');
      return;
    }
    if (_previewMismatch) {
      setState(() => _error = '请先「保存底座」，再保存下方 API 配置');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _note = null;
    });
    try {
      // sync controllers back into row maps
      final rows = _currentRows;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final slot = '${r['slot'] ?? ''}';
        final ed = _slotEdit[slot];
        if (ed == null) continue;
        if (slot == 'custom') {
          r['name'] = _ctrl('name', i, '${r['name'] ?? ''}').text.trim().toLowerCase();
        }
        if (ed.model) {
          r['model'] = _ctrl('model', i, '${r['model'] ?? ''}').text.trim();
        }
        if (ed.base) {
          r['baseUrl'] = _ctrl('base', i, '${r['baseUrl'] ?? ''}').text.trim();
        }
        r['keyNew'] = _ctrl('key', i, '').text.trim();
      }

      final payload = rows
          .where((r) => '${r['slot'] ?? ''}'.isNotEmpty)
          .map((r) {
        final slot = '${r['slot']}';
        final map = <String, dynamic>{
          'slot': slot,
          'name': slot == 'custom' ? '${r['name'] ?? ''}' : '',
          'model': _clean('${r['model']}'),
          'baseUrl': _clean('${r['baseUrl']}'),
          'key': '${r['keyNew'] ?? ''}',
          'primary': r['role'] == '主',
        };
        if (slot == 'custom') {
          map['protocol'] = '${r['protocol'] ?? r['type'] ?? 'openai'}';
          map['thinking'] = r['thinking'] == true;
          map['thinkingFormat'] = '${r['thinkingFormat'] ?? ''}';
        }
        return map;
      }).toList();

      final data = await widget.api.saveModels(channel: _chan, rows: payload);
      _ingestModels(data);
      setState(() {
        _note = data['note'] != null ? '✓ 已保存（${data['note']}）' : '✓ 已保存';
        _saving = false;
      });
      final boot = await widget.api.bootstrap();
      setState(() => _bootstrap = boot);
      if (boot['modelConfigured'] == true) widget.onConfigured?.call();
    } catch (e) {
      setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  Future<void> _doSelftest({required bool all}) async {
    if (_previewMismatch) {
      setState(() => _error = '请先「保存底座」再自测');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
      _note = null;
    });
    try {
      final channel = all ? _chan : (_chan == 'chat' ? 'chat' : _chan);
      final data = await widget.api.selftest(channel: channel);
      final byBase = <String, dynamic>{};
      for (final x in (data['results'] as List? ?? []).whereType<Map>()) {
        byBase['${x['baseUrl']}'] = Map<String, dynamic>.from(x);
      }
      setState(() {
        _selftestByBase = byBase;
        _selftestAt = (data['testedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
        _testing = false;
        if (byBase.isEmpty) {
          _note = '没有可自测的通道（未配置 key）';
        } else {
          final ok = byBase.values.whereType<Map>().where((e) => e['ok'] == true).length;
          _note = '自测完成：$ok / ${byBase.length} 通过';
        }
      });
    } catch (e) {
      setState(() {
        _error = '自测失败：$e';
        _testing = false;
      });
    }
  }

  void _setPrimary(int i) {
    setState(() {
      final rows = _currentRows;
      for (var j = 0; j < rows.length; j++) {
        if ('${rows[j]['slot'] ?? ''}'.isEmpty) continue;
        rows[j]['role'] = j == i ? '主' : '备';
      }
    });
  }

  void _addProvider() {
    setState(() {
      _channelRows['chat'] = [
        ...(_channelRows['chat'] ?? []),
        {
          'slot': 'custom',
          'order': 0,
          'name': '',
          'sub': '自定义',
          'type': 'openai',
          'protocol': 'openai',
          'model': '',
          'baseUrl': '',
          'keyMasked': '',
          'keyNew': '',
          'role': '备',
          'result': '待保存',
          'thinking': false,
          'thinkingFormat': 'openai',
        },
      ];
    });
  }

  void _removeRow(int i) {
    setState(() {
      final rows = List<Map<String, dynamic>>.from(_currentRows);
      final wasPrimary = rows[i]['role'] == '主';
      rows.removeAt(i);
      _clearChannelCtrls(_chan);
      if (wasPrimary) {
        for (final r in rows) {
          if ('${r['slot'] ?? ''}'.isNotEmpty) {
            r['role'] = '主';
            break;
          }
        }
      }
      _channelRows[_chan] = rows;
    });
  }

  Future<void> _enableLocalAgent(String id) async {
    setState(() {
      _enabling = id;
      _localAgentNote = null;
    });
    try {
      final d = await widget.api.enableLocalAgent(id, model: _laModels[id] ?? '');
      setState(() {
        _localAgentNote = '${d['note'] ?? '已接入'}';
        _localAgents = _localAgents
            .map((a) => '${a['id']}' == id ? {...a, 'configured': true} : a)
            .toList();
        _enabling = '';
      });
    } catch (e) {
      setState(() {
        _localAgentNote = '$e';
        _enabling = '';
      });
    }
  }

  Future<void> _pullModels(int i) async {
    final r = _currentRows[i];
    final slot = '${r['slot'] ?? ''}';
    final base = _ctrl('base', i, '${r['baseUrl'] ?? ''}').text.trim();
    final key = _ctrl('key', i, '').text.trim();
    final proto = slot == 'custom'
        ? '${r['protocol'] ?? r['type'] ?? 'openai'}'
        : ('${r['type']}' == 'anthropic' ? 'anthropic' : 'openai');
    setState(() => _note = '拉取模型中…');
    try {
      final d = await widget.api.availableModels(
        baseUrl: base,
        key: key,
        protocol: proto,
        slot: slot,
        name: '${r['name'] ?? ''}',
      );
      final models = (d['models'] as List? ?? []).map((e) => '$e').toList();
      if (!mounted) return;
      if (models.isEmpty) {
        setState(() => _note = '该端点没有返回模型');
        return;
      }
      final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(
          children: [
            for (final m in models)
              ListTile(
                title: Text(m),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      );
      if (picked != null) {
        _ctrl('model', i, '').text = picked;
        r['model'] = picked;
        setState(() => _note = '已选择模型：$picked');
      } else {
        setState(() => _note = '已拉取 ${models.length} 个模型');
      }
    } catch (e) {
      setState(() => _error = '拉取失败：$e');
    }
  }

  Future<void> _saveProxy() async {
    setState(() {
      _proxyBusy = true;
      _error = null;
    });
    try {
      final data = await widget.api.saveProxy(_proxyCtrl.text.trim());
      setState(() {
        _proxyCtrl.text = '${data['proxy'] ?? ''}';
        _proxySource = '${data['source'] ?? 'none'}';
        _note = _proxyCtrl.text.isEmpty ? '已清除代理配置' : '已保存：${_proxyCtrl.text} —— 立即生效，无需重启';
        _proxyBusy = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _proxyBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner ??
        (_bootstrap != null && _bootstrap!['modelConfigured'] != true
            ? '尚未配置可用模型。请在「OpenClaw API 配置」中填写 Key，或切换已配置底座。'
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHead(),
        if (banner != null && banner.isNotEmpty)
          MaterialBanner(
            content: Text(banner),
            leading: const Icon(Icons.info_outline),
            actions: [
              TextButton(
                onPressed: () => setState(() => _sec = 0),
                child: const Text('去配置'),
              ),
            ],
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_note!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                extended: true,
                minExtendedWidth: 140,
                selectedIndex: _sec,
                onDestinationSelected: (i) => setState(() => _sec = i),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune),
                    label: Text('模型配置'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: Text('环境安装'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more_horiz),
                    label: Text('更多设置'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : switch (_sec) {
                        0 => _buildModelMain(),
                        1 => EnvPage(api: widget.api),
                        _ => _buildMore(),
                      },
              ),
            ],
          ),
        ),
        _buildFoot(),
      ],
    );
  }

  Widget _buildHead() {
    final canSaveApi = !_saving &&
        !_previewMismatch &&
        (_chan != 'chat' ||
            _selectedHarness == 'api' ||
            _selectedHarness == 'openclaw');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设置', style: Theme.of(context).textTheme.titleLarge),
              Text('模型配置 · 环境安装 · 更多设置',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: canSaveApi ? _saveConfig : null,
            child: Text(_saving ? '保存中…' : '保存配置'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _testing || _previewMismatch
                ? null
                : () => _doSelftest(all: true),
            child: Text(_testing ? '自测中…' : '全部自测'),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _reloadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildFoot() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Text(
        'ⓘ 供应商配置保存到 .env；API 直连仅聊天、无工具。切换底座或对话模式后请新建对话。',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildModelMain() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (id, label) in _channels)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _chan == id,
                    onSelected: (_) async {
                      setState(() => _chan = id);
                      // rows already loaded with all channels
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_chan == 'chat') ...[
          _buildHarnessPanel(),
          const SizedBox(height: 12),
        ],
        if (_apiPanelVisible) ...[
          _buildApiPanel(),
          const SizedBox(height: 12),
        ],
        if (_chan != 'chat' ||
            (_selectedHarness != 'api' && _selectedHarness != 'openclaw'))
          _buildGenericChannelBoard(),
      ],
    );
  }

  Widget _buildHarnessPanel() {
    final ids = _agents.isEmpty
        ? const ['api', 'openclaw']
        : _agents.map((a) => '${a['id']}').toList();
    final value = ids.contains(_selectedHarness) ? _selectedHarness : ids.first;
    String desc;
    if (_selectedHarness == 'api') {
      desc = '模型 API 直连 · 无需安装 Agent，模型在下方配置';
    } else if (_selectedHarness == 'openclaw') {
      desc = 'OpenClaw 的模型、API 地址和 Key 在下方配置，保存后同步到 gateway';
    } else {
      desc = '安装可选 OpenClaw 或其它 Agent CLI；只有「保存底座」才切换生效。';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Agent 底座', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton(
                  onPressed: _locked || _saving ? null : _saveHarness,
                  child: const Text('保存底座'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _rereadHarness,
                  child: const Text('重新读取'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('选择仅聊天，或使用 Agent 执行工具',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: '执行引擎',
                border: const OutlineInputBorder(),
                helperText: _locked ? '已由启动环境 EASEL_AGENT_RUNTIME 锁定' : null,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: value,
                  items: [
                    for (final id in ids)
                      DropdownMenuItem(value: id, child: Text(_agentLabel(id))),
                  ],
                  onChanged: _locked
                      ? null
                      : (v) async {
                          if (v == null) return;
                          setState(() {
                            _selectedHarness = v;
                            _nativeModel.text = '';
                          });
                          try {
                            await _loadModelsForSelected();
                            setState(() {});
                          } catch (e) {
                            setState(() => _error = '$e');
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(desc, style: Theme.of(context).textTheme.bodySmall),
            if (_previewMismatch)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '当前为配置预览；请先「保存底座」，再保存下方 API 配置。旧对话不迁移。',
                  style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                ),
              ),
            if (_selectedHarness != 'api' && _selectedHarness != 'openclaw') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nativeModel,
                decoration: const InputDecoration(
                  labelText: '模型覆盖（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '沙箱权限',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _sandbox,
                    items: const [
                      DropdownMenuItem(value: 'read-only', child: Text('只读')),
                      DropdownMenuItem(
                          value: 'workspace-write', child: Text('工作区可写')),
                    ],
                    onChanged: (v) => setState(() => _sandbox = v ?? _sandbox),
                  ),
                ),
              ),
              if (_selectedHarness == 'codex')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Codex 自动批准'),
                  value: _codexAuto,
                  onChanged: (v) => setState(() => _codexAuto = v),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _agentLabel(String id) {
    for (final a in _agents) {
      if ('${a['id']}' == id) {
        final label = '${a['label'] ?? id}';
        final installed = a['installed'] == true;
        return installed ? label : '$label（未安装 / 未配置）';
      }
    }
    return id;
  }

  Widget _buildApiPanel() {
    final isApi = _selectedHarness == 'api';
    final title = isApi ? '仅聊天模式 API 配置' : 'OpenClaw API 配置';
    String? selftestDesc;
    if (_selftestAt != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(_selftestAt! * 1000);
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      selftestDesc = '上次自测 $hh:$mm';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Chip(
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: _chatOk ? Colors.green : Colors.orange,
                  ),
                  label: Text(_chatOk ? '已配置' : '未配置'),
                  visualDensity: VisualDensity.compact,
                ),
                if (selftestDesc != null) ...[
                  const SizedBox(width: 8),
                  Text(selftestDesc, style: Theme.of(context).textTheme.bodySmall),
                ],
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _testing || _previewMismatch
                      ? null
                      : () => _doSelftest(all: false),
                  child: const Text('自测本通道'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBoard(_channelRows['chat'] ?? [], channel: 'chat'),
            const SizedBox(height: 8),
            if (isApi)
              Text(
                '此通道使用独立的 EASEL_DIRECT_API_* 配置。没有本机文件、浏览器或技能执行工具。',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              OutlinedButton(
                onPressed: _addProvider,
                child: const Text(
                  '＋ 添加供应商（填名称 / 模型 / Base URL / Key；点「设为主」切换生效通道）',
                ),
              ),
            if (_harness == 'openclaw') ...[
              const SizedBox(height: 16),
              _buildLocalAgents(),
            ],
            const SizedBox(height: 8),
            Text(
              '改完点右上角「保存配置」（key 留空=不改）；自动降级链随统一网关接入开放。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericChannelBoard() {
    if (_chan == 'chat') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            '当前底座为 $_selectedHarness。请用上方「保存底座」保存原生配置；API 供应商表仅在 api / openclaw 下显示。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _channels.firstWhere((e) => e.$1 == _chan).$2,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _testing ? null : () => _doSelftest(all: false),
                  child: const Text('自测本通道'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBoard(_currentRows, channel: _chan),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(List<Map<String, dynamic>> rows, {required String channel}) {
    if (rows.isEmpty) {
      return const Text('暂无供应商行');
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          _providerCard(rows, i, channelOverride: channel),
      ],
    );
  }

  Widget _providerCard(
    List<Map<String, dynamic>> rows,
    int i, {
    required String channelOverride,
  }) {
    // Hack: controller keys use _chan — temporarily set
    final savedChan = _chan;
    _chan = channelOverride;
    final r = rows[i];
    final slot = '${r['slot'] ?? ''}';
    final ed = _slotEdit[slot];
    final isCustom = slot == 'custom';
    final order = r['order'] == 0 || r['order'] == null
        ? (isCustom ? '${i + 1}' : '—')
        : '${r['order']}';
    final role = '${r['role'] ?? ''}';
    final resultText = _resultText(r);

    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 28,
                    child: Text(order,
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                ),
                Expanded(
                  child: isCustom
                      ? TextField(
                          controller: _ctrl('name', i, '${r['name'] ?? ''}'),
                          decoration: const InputDecoration(
                            labelText: '供应商名称',
                            hintText: '名称',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => r['name'] = v.trim().toLowerCase(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r['name'] ?? slot}',
                                style: Theme.of(context).textTheme.titleSmall),
                            if ('${r['sub'] ?? ''}'.isNotEmpty)
                              Text('${r['sub']}',
                                  style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                if (isCustom)
                  SizedBox(
                    width: 148,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: '${r['protocol'] ?? r['type'] ?? 'openai'}',
                      decoration: const InputDecoration(
                        labelText: '类型',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'openai',
                          child: Text('openai', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'anthropic',
                          child:
                              Text('anthropic', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        r['protocol'] = v;
                        r['type'] = v;
                      }),
                    ),
                  )
                else
                  Chip(
                    label: Text('${r['type'] ?? ''}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (isCustom)
                  IconButton(
                    tooltip: '删除',
                    onPressed: () {
                      _chan = channelOverride;
                      _removeRow(i);
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ctrl('model', i, '${r['model'] ?? ''}'),
                    enabled: ed?.model ?? false,
                    decoration: InputDecoration(
                      labelText: '模型',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: (ed?.model ?? false)
                          ? IconButton(
                              tooltip: '拉取模型',
                              onPressed: () {
                                _chan = channelOverride;
                                _pullModels(i);
                              },
                              icon: const Icon(Icons.download),
                            )
                          : null,
                    ),
                    onChanged: (v) => r['model'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ctrl('base', i, '${r['baseUrl'] ?? ''}'),
                    enabled: ed?.base ?? false,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => r['baseUrl'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _ctrl('key', i, ''),
                    obscureText: true,
                    enabled: ed != null,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: '${r['keyMasked'] ?? ''}'.isNotEmpty
                          ? '${r['keyMasked']}'
                          : '粘贴 Key',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => r['keyNew'] = v,
                  ),
                ),
              ],
            ),
            if (isCustom) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: r['thinking'] == true,
                    onChanged: (v) => setState(() => r['thinking'] = v ?? false),
                  ),
                  const Text('该模型会思考'),
                  if (r['thinking'] == true &&
                      '${r['protocol'] ?? r['type']}' != 'anthropic') ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _thinkingFormats
                                .any((e) => e.$1 == '${r['thinkingFormat'] ?? ''}')
                            ? '${r['thinkingFormat'] ?? ''}'
                            : '',
                        decoration: const InputDecoration(
                          labelText: '思考格式',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final (v, label) in _thinkingFormats)
                            DropdownMenuItem(
                              value: v,
                              child: Text(label, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => r['thinkingFormat'] = v ?? ''),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                ActionChip(
                  label: Text(role.isEmpty ? '备' : role),
                  avatar: Icon(
                    role == '主' ? Icons.star : Icons.star_border,
                    size: 16,
                  ),
                  onPressed: slot.isEmpty
                      ? null
                      : () {
                          _chan = channelOverride;
                          _setPrimary(i);
                        },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    resultText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: resultText.startsWith('✓')
                              ? Colors.green.shade800
                              : resultText.startsWith('✗')
                                  ? Colors.red.shade800
                                  : null,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    _chan = savedChan;
    return card;
  }

  String _resultText(Map<String, dynamic> r) {
    final base = _clean('${r['baseUrl']}');
    final st = _selftestByBase?[base];
    if (st is Map) {
      if (st['ok'] == true) return '✓ ${st['ms']}ms';
      return '✗ ${st['detail'] ?? '失败'}';
    }
    return '${r['result'] ?? ''}';
  }

  Widget _buildLocalAgents() {
    if (_localAgentsErr != null) {
      return Text('本机 agent 探测失败：$_localAgentsErr',
          style: Theme.of(context).textTheme.bodySmall);
    }
    if (_localAgents.isEmpty) {
      return Text('未检测到已安装的本机 Agent CLI',
          style: Theme.of(context).textTheme.bodySmall);
    }
    final usable = _localAgents
        .where((a) => a['usableWithoutKey'] == true)
        .map((a) => '${a['label'] ?? a['id']}')
        .join('、');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('本机 Agent', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          usable.isNotEmpty
              ? '检测到可免 API Key 使用：$usable'
              : '检测到的 CLI 暂无底座后端，仍需填 API Key',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final a in _localAgents) _localAgentRow(a),
        if (_localAgentNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_localAgentNote!,
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _localAgentRow(Map<String, dynamic> a) {
    final id = '${a['id']}';
    final configured = a['configured'] == true;
    final supported = a['supported'] != false;
    final models = (a['models'] as List? ?? []).map((e) => '$e').toList();
    final pill = !supported
        ? '暂不支持'
        : configured
            ? '已接入'
            : '可接入';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${a['label'] ?? id}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pill),
            if ('${a['loginHint'] ?? ''}'.isNotEmpty)
              Text('${a['loginHint']}',
                  style: Theme.of(context).textTheme.bodySmall),
            if (models.isNotEmpty)
              DropdownButton<String>(
                isExpanded: true,
                value: _laModels[id] ?? '',
                items: [
                  const DropdownMenuItem(value: '', child: Text('默认模型')),
                  for (final m in models)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setState(() => _laModels[id] = v ?? ''),
              ),
          ],
        ),
        trailing: FilledButton.tonal(
          onPressed: !supported || _enabling == id
              ? null
              : () => _enableLocalAgent(id),
          child: Text(_enabling == id
              ? '接入中…'
              : configured
                  ? '应用模型'
                  : '一键接入'),
        ),
      ),
    );
  }

  Widget _buildMore() {
    final readOnly = _proxySource == 'env';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('网络代理', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'EASEL_PROXY。形如 http://127.0.0.1:7890（不含用户名密码）',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _proxyCtrl,
          enabled: !readOnly && !_proxyBusy,
          decoration: InputDecoration(
            labelText: '代理地址',
            border: const OutlineInputBorder(),
            helperText: readOnly
                ? '启动环境已固定 EASEL_PROXY（只读）'
                : '来源：$_proxySource；空串保存=清除',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: readOnly || _proxyBusy ? null : _saveProxy,
              child: const Text('保存代理'),
            ),
            OutlinedButton(
              onPressed: readOnly || _proxyBusy
                  ? null
                  : () {
                      _proxyCtrl.clear();
                      _saveProxy();
                    },
              child: const Text('清除'),
            ),
          ],
        ),
        const Divider(height: 32),
        if (_bootstrap != null) ...[
          Text('Bootstrap', style: Theme.of(context).textTheme.titleMedium),
          _kv('modelConfigured', '${_bootstrap!['modelConfigured']}'),
          _kv('envKeyOk', '${_bootstrap!['envKeyOk']}'),
          _kv('routeOk', '${_bootstrap!['routeOk']}'),
          _kv('routeDetail', '${_bootstrap!['routeDetail'] ?? ''}'),
          _kv('gatewayUp', '${_bootstrap!['gatewayUp']}'),
        ],
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 140,
                child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: SelectableText(v)),
          ],
        ),
      );
}
