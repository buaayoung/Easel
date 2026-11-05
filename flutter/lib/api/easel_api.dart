import 'dart:convert';

import 'package:http/http.dart' as http;

class EnvTool {
  EnvTool(this.json);

  final Map<String, dynamic> json;

  String get id => '${json['id'] ?? ''}';
  String get name => '${json['name'] ?? id}';
  String get state => '${json['state'] ?? 'missing'}';
  String? get version => json['version']?.toString();
  String? get detail => json['detail']?.toString();
  bool get big => json['big'] == true;
  bool get bundled => json['bundled'] == true;
  bool get onDemand => json['onDemand'] == true || id == 'model';
  String get groupName => '${json['group_name'] ?? json['group'] ?? ''}';
}

/// Backend display placeholders — strip before save (same as web SettingsPanel).
const modelPlaceholders = {'—', '官方', '（未配置）', '本机', '内建默认'};

class ModelRow {
  ModelRow(this.json);

  final Map<String, dynamic> json;

  String get slot => '${json['slot'] ?? ''}';
  String get name => '${json['name'] ?? slot}';
  String get sub => '${json['sub'] ?? ''}';
  String get model => '${json['model'] ?? ''}';
  String get baseUrl => '${json['baseUrl'] ?? ''}';
  String get keyMasked => '${json['keyMasked'] ?? ''}';
  String get role => '${json['role'] ?? ''}';
  String get result => '${json['result'] ?? ''}';
  String get protocol => '${json['protocol'] ?? 'openai'}';
  bool get modelEditable => json['modelEditable'] != false;
  bool get baseEditable => json['baseEditable'] == true;
  bool get deletable => json['deletable'] == true;

  String cleanModel() {
    final v = model.trim();
    return modelPlaceholders.contains(v) ? '' : v;
  }

  String cleanBaseUrl() {
    final v = baseUrl.trim();
    return modelPlaceholders.contains(v) ? '' : v;
  }
}

class EaselApi {
  EaselApi(this.baseUrl);

  final String baseUrl;

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(_u('/api/health'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> envTools({bool refresh = false}) async {
    final r = await http.get(_u('/api/env/tools', {'refresh': refresh ? '1' : '0'}));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<String> installTool(String id, {String? dir}) async {
    final body = <String, dynamic>{'id': id};
    if (dir != null) body['dir'] = dir;
    final r = await http.post(
      _u('/api/env/install'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return '${data['jobId']}';
  }

  Future<Map<String, dynamic>> installJob(String jobId) async {
    final r = await http.get(_u('/api/env/job/$jobId'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chat({
    required String message,
    String? sessionId,
  }) async {
    final r = await http.post(
      _u('/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'sessionId': ?sessionId,
      }),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bootstrap() async {
    final r = await http.get(_u('/api/settings/bootstrap'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> harness() async {
    final r = await http.get(_u('/api/settings/harness'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveHarness({
    required String runtime,
    String model = '',
    String sandbox = 'workspace-write',
    bool? codexAutoApprove,
  }) async {
    final body = <String, dynamic>{
      'runtime': runtime,
      'model': model,
      'sandbox': sandbox,
    };
    if (codexAutoApprove != null) body['codex_auto_approve'] = codexAutoApprove;
    final r = await http.post(
      _u('/api/settings/harness'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> models({String? runtime}) async {
    final r = await http.get(
      _u('/api/settings/models', runtime == null ? null : {'runtime': runtime}),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveModels({
    required String channel,
    required List<Map<String, dynamic>> rows,
  }) async {
    final r = await http.post(
      _u('/api/settings/models/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channel': channel, 'rows': rows}),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> selftest({String channel = 'chat'}) async {
    final r = await http.post(
      _u('/api/settings/models/selftest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channel': channel}),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> proxy() async {
    final r = await http.get(_u('/api/settings/proxy'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveProxy(String proxy) async {
    final r = await http.post(
      _u('/api/settings/proxy'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'proxy': proxy}),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> localAgents() async {
    final r = await http.get(_u('/api/settings/local-agents'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enableLocalAgent(String id, {String model = ''}) async {
    final r = await http.post(
      _u('/api/settings/local-agents/enable'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'model': model}),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gatewayRestart() async {
    final r = await http.post(_u('/api/gateway/restart'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> availableModels({
    required String baseUrl,
    String key = '',
    String protocol = 'openai',
    String slot = '',
    String name = '',
  }) async {
    final r = await http.post(
      _u('/api/settings/models/available'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'baseUrl': baseUrl,
        'key': key,
        'protocol': protocol,
        'slot': slot,
        'name': name,
      }),
    );
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  void _ensureOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    String detail = r.body;
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['detail'] != null) detail = '${body['detail']}';
    } catch (_) {}
    throw StateError('HTTP ${r.statusCode}: $detail');
  }
}
