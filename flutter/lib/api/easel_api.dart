import 'dart:async';
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

typedef StreamTokenCb = void Function(String chunk);
typedef StreamDoneCb = void Function(String? sessionKey);
typedef StreamErrorCb = void Function(Object err);

class EaselApi {
  EaselApi(this.baseUrl);

  final String baseUrl;

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? q]) async {
    final r = await http.get(_u(path, q));
    _ensureOk(r);
    return _asMap(r.body);
  }

  Future<Map<String, dynamic>> _post(String path, [Object? body]) async {
    final r = await http.post(
      _u(path),
      headers: {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
    _ensureOk(r);
    if (r.body.isEmpty) return {};
    return _asMap(r.body);
  }

  Future<Map<String, dynamic>> _put(String path, Object body) async {
    final r = await http.put(
      _u(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(r);
    return _asMap(r.body);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final r = await http.delete(_u(path));
    _ensureOk(r);
    return r.body.isEmpty ? {'ok': true} : _asMap(r.body);
  }

  Future<List<dynamic>> _getList(String path, [Map<String, String>? q]) async {
    final r = await http.get(_u(path, q));
    _ensureOk(r);
    final decoded = jsonDecode(r.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['items'] is List) return decoded['items'] as List;
    if (decoded is Map && decoded['data'] is List) return decoded['data'] as List;
    return const [];
  }

  Map<String, dynamic> _asMap(String body) {
    final d = jsonDecode(body);
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return {'value': d};
  }

  // ---- core ----
  Future<Map<String, dynamic>> health() => _get('/api/health');

  Future<Map<String, dynamic>> status() => _get('/api/status');

  Future<List<Map<String, dynamic>>> personas() async {
    final list = await _getList('/api/personas');
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> personaFiles(String name) =>
      _get('/api/persona/${Uri.encodeComponent(name)}/files');

  Future<Map<String, dynamic>> savePersonaFile(String name, String filename, String content) =>
      _put('/api/persona/${Uri.encodeComponent(name)}/file', {
        'filename': filename,
        'content': content,
      });

  Future<Map<String, dynamic>> deletePersona(String name) =>
      _delete('/api/persona/${Uri.encodeComponent(name)}');

  Future<Map<String, dynamic>> envTools({bool refresh = false}) =>
      _get('/api/env/tools', {'refresh': refresh ? '1' : '0'});

  Future<String> installTool(String id, {String? dir}) async {
    final data = await _post('/api/env/install', {
      'id': id,
      if (dir != null) 'dir': dir,
    });
    return '${data['jobId']}';
  }

  Future<Map<String, dynamic>> installJob(String jobId) => _get('/api/env/job/$jobId');

  Future<Map<String, dynamic>> bootstrap() => _get('/api/settings/bootstrap');

  Future<Map<String, dynamic>> harness() => _get('/api/settings/harness');

  Future<Map<String, dynamic>> saveHarness({
    required String runtime,
    String model = '',
    String sandbox = 'workspace-write',
    bool? codexAutoApprove,
  }) =>
      _post('/api/settings/harness', {
        'runtime': runtime,
        'model': model,
        'sandbox': sandbox,
        if (codexAutoApprove != null) 'codex_auto_approve': codexAutoApprove,
      });

  Future<Map<String, dynamic>> models({String? runtime}) =>
      _get('/api/settings/models', runtime == null ? null : {'runtime': runtime});

  Future<Map<String, dynamic>> saveModels({
    required String channel,
    required List<Map<String, dynamic>> rows,
  }) =>
      _post('/api/settings/models/save', {'channel': channel, 'rows': rows});

  Future<Map<String, dynamic>> selftest({String channel = 'chat'}) =>
      _post('/api/settings/models/selftest', {'channel': channel});

  Future<Map<String, dynamic>> proxy() => _get('/api/settings/proxy');

  Future<Map<String, dynamic>> saveProxy(String proxy) =>
      _post('/api/settings/proxy', {'proxy': proxy});

  Future<Map<String, dynamic>> localAgents() => _get('/api/settings/local-agents');

  Future<Map<String, dynamic>> enableLocalAgent(String id, {String model = ''}) =>
      _post('/api/settings/local-agents/enable', {'id': id, 'model': model});

  Future<Map<String, dynamic>> gatewayRestart() => _post('/api/gateway/restart');

  Future<Map<String, dynamic>> availableModels({
    required String baseUrl,
    String key = '',
    String protocol = 'openai',
    String slot = '',
    String name = '',
  }) =>
      _post('/api/settings/models/available', {
        'baseUrl': baseUrl,
        'key': key,
        'protocol': protocol,
        'slot': slot,
        'name': name,
      });

  Future<Map<String, dynamic>> stopChat(String sessionId) =>
      _post('/api/chat/stop', {'sessionId': sessionId});

  Future<Map<String, dynamic>> deleteRemoteSession(String sessionKey) =>
      _delete('/api/session/${Uri.encodeComponent(sessionKey)}');

  Future<Map<String, dynamic>> chat({
    required String message,
    String? sessionId,
    String? persona,
  }) =>
      _post('/api/chat', {
        'message': message,
        if (sessionId != null) 'sessionId': sessionId,
        if (persona != null && persona.isNotEmpty) 'persona': persona,
      });

  /// SSE chat stream. Returns a cancel callback.
  Future<void> Function() streamChat({
    required String message,
    required String sessionId,
    String? persona,
    String? turnId,
    required StreamTokenCb onToken,
    void Function(String chunk)? onThinking,
    void Function(String status)? onActivity,
    required StreamDoneCb onDone,
    required StreamErrorCb onError,
  }) {
    final client = http.Client();
    var cancelled = false;
    final completer = Completer<void>();

    Future<void> run() async {
      try {
        final req = http.Request('POST', _u('/api/chat/stream'));
        req.headers['Content-Type'] = 'application/json';
        req.headers['Accept'] = 'text/event-stream';
        req.body = jsonEncode({
          'message': message,
          'sessionId': sessionId,
          if (persona != null && persona.isNotEmpty) 'persona': persona,
          if (turnId != null) 'turnId': turnId,
        });
        final res = await client.send(req);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          final body = await res.stream.bytesToString();
          throw StateError('HTTP ${res.statusCode}: $body');
        }

        var buffer = '';
        var currentEvent = '';
        final dataLines = <String>[];

        bool dispatch() {
          if (currentEvent.isEmpty || dataLines.isEmpty) return false;
          final data = dataLines.join('\n');
          if (currentEvent == 'token') {
            try {
              onToken(jsonDecode(data) as String);
            } catch (_) {
              onToken(data);
            }
          } else if (currentEvent == 'thinking') {
            final cb = onThinking;
            if (cb != null) {
              try {
                cb(jsonDecode(data) as String);
              } catch (_) {
                cb(data);
              }
            }
          } else if (currentEvent == 'activity') {
            final cb = onActivity;
            if (cb != null) {
              try {
                cb(jsonDecode(data) as String);
              } catch (_) {
                cb(data);
              }
            }
          } else if (currentEvent == 'error') {
            var msg = '执行失败';
            try {
              msg = jsonDecode(data) as String;
            } catch (_) {
              msg = data;
            }
            onError(StateError(msg));
            return true;
          } else if (currentEvent == 'done') {
            String? key;
            try {
              final m = jsonDecode(data);
              if (m is Map) key = m['sessionKey']?.toString();
            } catch (_) {}
            onDone(key);
            return true;
          }
          return false;
        }

        await for (final chunk in res.stream.transform(utf8.decoder)) {
          if (cancelled) break;
          buffer += chunk;
          final lines = buffer.split(RegExp(r'\r?\n'));
          buffer = lines.removeLast();
          for (final line in lines) {
            if (line.isEmpty) {
              if (dispatch()) {
                if (!completer.isCompleted) completer.complete();
                return;
              }
              currentEvent = '';
              dataLines.clear();
            } else if (line.startsWith('event:')) {
              currentEvent = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              var d = line.substring(5);
              if (d.startsWith(' ')) d = d.substring(1);
              dataLines.add(d);
            }
          }
        }
        if (!completer.isCompleted) {
          onDone(null);
          completer.complete();
        }
      } catch (e) {
        if (!cancelled) onError(e);
        if (!completer.isCompleted) completer.complete();
      } finally {
        client.close();
      }
    }

    unawaited(run());
    return () async {
      cancelled = true;
      client.close();
      if (!completer.isCompleted) completer.complete();
      await completer.future;
    };
  }

  // ---- domain ----
  /// Web 同构：`{ version, trends: TrendGroup[], updated, warnings }`。
  /// 采集可能较慢，超时对齐前端 130s。
  Future<Map<String, dynamic>> trends({String? platforms, int limit = 12}) async {
    final r = await http
        .get(_u('/api/trends', {
          if (platforms != null) 'platforms': platforms,
          'limit': '$limit',
        }))
        .timeout(const Duration(seconds: 130));
    _ensureOk(r);
    return _asMap(r.body);
  }

  Future<Map<String, dynamic>> trendSources() async {
    final r = await http
        .get(_u('/api/trends/sources'))
        .timeout(const Duration(seconds: 30));
    _ensureOk(r);
    return _asMap(r.body);
  }

  Future<List<Map<String, dynamic>>> ideas() async {
    final list = await _getList('/api/ideas');
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createIdea(Map<String, dynamic> item) => _post('/api/ideas', item);

  Future<Map<String, dynamic>> updateIdea(String id, Map<String, dynamic> item) =>
      _put('/api/ideas/${Uri.encodeComponent(id)}', item);

  Future<Map<String, dynamic>> deleteIdea(String id) =>
      _delete('/api/ideas/${Uri.encodeComponent(id)}');

  Future<List<Map<String, dynamic>>> schedule() async {
    final list = await _getList('/api/schedule');
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createSchedule(Map<String, dynamic> item) =>
      _post('/api/schedule', item);

  Future<Map<String, dynamic>> updateSchedule(String id, Map<String, dynamic> item) =>
      _put('/api/schedule/${Uri.encodeComponent(id)}', item);

  Future<Map<String, dynamic>> deleteSchedule(String id) =>
      _delete('/api/schedule/${Uri.encodeComponent(id)}');

  Future<List<Map<String, dynamic>>> skills() async {
    final list = await _getList('/api/skills');
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> skillDetail(String name) =>
      _get('/api/skill/${Uri.encodeComponent(name)}');

  Future<Map<String, dynamic>> executeSkill(String skill, String input, {String? persona}) =>
      _post('/api/skill', {
        'skill': skill,
        'input': input,
        if (persona != null && persona.isNotEmpty) 'persona': persona,
      });

  Future<List<Map<String, dynamic>>> outputs() async {
    final list = await _getList('/api/outputs');
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> outputContent(String path) =>
      _get('/api/output/${path.split('/').map(Uri.encodeComponent).join('/')}');

  Future<Map<String, dynamic>> deleteOutput(String path) =>
      _delete('/api/output/${path.split('/').map(Uri.encodeComponent).join('/')}');

  String mediaUrl(String path) =>
      '$baseUrl/api/media/${path.split('/').map(Uri.encodeComponent).join('/')}';

  Future<List<Map<String, dynamic>>> accounts() async {
    final list = await _getList('/api/accounts');
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> accountWhoami(String platform, {bool force = false}) =>
      _get('/api/accounts/${Uri.encodeComponent(platform)}/whoami', {
        if (force) 'force': '1',
      });

  Future<Map<String, dynamic>> startLogin(String platform) =>
      _post('/api/login/${Uri.encodeComponent(platform)}');

  Future<Map<String, dynamic>> loginStatus(String platform) =>
      _get('/api/login/${Uri.encodeComponent(platform)}/status');

  Future<Map<String, dynamic>> submitLoginSms(String platform, String code) =>
      _post('/api/login/${Uri.encodeComponent(platform)}/sms', {'code': code});

  Future<Map<String, dynamic>> getCredentials(String platform) =>
      _get('/api/accounts/${Uri.encodeComponent(platform)}/credentials');

  Future<Map<String, dynamic>> saveCredentials(
    String platform, {
    required String appId,
    required String appSecret,
    String name = '',
    String author = '',
  }) =>
      _post('/api/accounts/${Uri.encodeComponent(platform)}/credentials', {
        'appId': appId,
        'appSecret': appSecret,
        if (name.isNotEmpty) 'name': name,
        if (author.isNotEmpty) 'author': author,
      });

  Future<Map<String, dynamic>> startMpLogin(String platform) =>
      _post('/api/accounts/${Uri.encodeComponent(platform)}/mp-login');

  Future<Map<String, dynamic>> mpLoginStatus(String platform) =>
      _get('/api/accounts/${Uri.encodeComponent(platform)}/mp-login/status');

  Future<Map<String, dynamic>> logoutAccount(String platform) =>
      _post('/api/logout/${Uri.encodeComponent(platform)}');

  Future<Map<String, dynamic>> buildProfile(String name, Map<String, dynamic> form) =>
      _post('/api/profile/build', {'name': name, 'form': form});

  Future<Map<String, dynamic>> profileBuildStatus(String name) =>
      _get('/api/profile/build/status/${Uri.encodeComponent(name)}');

  Future<Map<String, dynamic>> publishingPolicy() => _get('/api/publishing-policy');

  Future<Map<String, dynamic>> publishNow(String platform, Map<String, dynamic> payload) =>
      _post('/api/publish/${Uri.encodeComponent(platform)}', payload);

  Future<Map<String, dynamic>> publishStatus(String platform) =>
      _get('/api/publish/${Uri.encodeComponent(platform)}/status');

  Future<Map<String, dynamic>> exportManual(String platform, Map<String, dynamic> payload) =>
      _post('/api/manual-publish/${Uri.encodeComponent(platform)}/export', payload);

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
