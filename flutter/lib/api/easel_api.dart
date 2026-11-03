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

class EaselApi {
  EaselApi(this.baseUrl);

  final String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(_u('/api/health'));
    _ensureOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> envTools({bool refresh = false}) async {
    final r = await http.get(_u('/api/env/tools?refresh=${refresh ? 1 : 0}'));
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

  void _ensureOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    throw StateError('HTTP ${r.statusCode}: ${r.body}');
  }
}
