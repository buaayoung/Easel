import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_session.dart';

const _sessionsKey = 'easel_sessions';
const _activeKey = 'easel_active_session';
const _maxSessions = 100;
const _titleMax = 24;

String generateSessionId() {
  final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rand = (DateTime.now().microsecondsSinceEpoch % 0xffffff).toRadixString(36);
  return '$now$rand';
}

ChatSession createSession({String? persona}) => ChatSession(
      id: generateSessionId(),
      title: '新对话',
      persona: persona,
    );

String titleFromMessage(String text) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return '新对话';
  return t.length <= _titleMax ? t : '${t.substring(0, _titleMax)}…';
}

class SessionStore {
  Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = sessions.take(_maxSessions).toList();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(trimmed.map((s) => s.toJson()).toList()),
    );
  }

  Future<String?> loadActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> saveActiveId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
  }
}
