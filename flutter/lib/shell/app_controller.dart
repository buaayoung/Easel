import 'package:flutter/foundation.dart';

import '../api/easel_api.dart';
import '../models/chat_session.dart';
import '../services/session_store.dart';
import '../sidecar/paths.dart';
import '../sidecar/sidecar_launcher.dart';

class AppController extends ChangeNotifier {
  final SessionStore _store = SessionStore();

  EaselPaths? paths;
  SidecarLauncher? launcher;
  EaselApi? api;
  String? bootError;
  bool booting = true;

  AppPage currentPage = AppPage.dashboard;
  List<ChatSession> sessions = [];
  String? activeSessionId;
  List<Map<String, dynamic>> personas = [];
  String selectedPersona = '';
  String gatewayStatus = 'connecting';
  bool apiDirect = false;
  String agentRuntime = 'openclaw';
  bool settingsOpen = false;
  bool wizardOpen = false;
  bool modelConfigured = true;
  StreamState? stream;
  Future<void> Function()? _cancelStream;

  ChatSession? get activeSession {
    final id = activeSessionId;
    if (id == null) return null;
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> boot() async {
    booting = true;
    bootError = null;
    notifyListeners();
    try {
      paths = await EaselPaths.resolve();
      launcher = SidecarLauncher(paths!);
      await launcher!.start();
      if (launcher!.state != SidecarState.ready) {
        bootError = launcher!.lastError ?? 'sidecar 启动失败';
      } else {
        api = EaselApi(launcher!.baseUrl);
        await _loadLocalSessions();
        await refreshStatus();
        await refreshPersonas();
        await _checkBootstrap();
      }
    } catch (e) {
      bootError = '$e';
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalSessions() async {
    sessions = await _store.loadSessions();
    final active = await _store.loadActiveId();
    if (active != null && sessions.any((s) => s.id == active)) {
      activeSessionId = active;
      selectedPersona =
          sessions.firstWhere((s) => s.id == active).persona ?? '';
    } else if (sessions.isNotEmpty) {
      activeSessionId = sessions.first.id;
      selectedPersona = sessions.first.persona ?? '';
    } else {
      final s = createSession();
      sessions = [s];
      activeSessionId = s.id;
      await _persist();
    }
  }

  Future<void> _checkBootstrap() async {
    final a = api;
    if (a == null) return;
    try {
      final boot = await a.bootstrap();
      modelConfigured = boot['modelConfigured'] == true;
      if (!modelConfigured) settingsOpen = true;
    } catch (_) {}
  }

  Future<void> refreshStatus() async {
    final a = api;
    if (a == null) return;
    try {
      final st = await a.status();
      // 对齐 Web StatusResponse：{ gateway: bool, transport, runtime }
      final transport = '${st['transport'] ?? ''}';
      apiDirect = transport == 'api' || st['apiDirect'] == true;
      agentRuntime = '${st['runtime'] ?? st['agentRuntime'] ?? 'openclaw'}';
      final ready = st['gateway'] == true;
      gatewayStatus = ready ? 'connected' : 'disconnected';
      notifyListeners();
    } catch (_) {
      gatewayStatus = 'disconnected';
      notifyListeners();
    }
  }

  Future<void> refreshPersonas() async {
    final a = api;
    if (a == null) return;
    try {
      personas = await a.personas();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    await _store.saveSessions(sessions);
    await _store.saveActiveId(activeSessionId);
  }

  void setPage(AppPage page) {
    currentPage = page;
    notifyListeners();
  }

  void openSettings() {
    settingsOpen = true;
    notifyListeners();
  }

  void closeSettings() {
    settingsOpen = false;
    notifyListeners();
    refreshStatus();
  }

  void openWizard() {
    wizardOpen = true;
    notifyListeners();
  }

  void closeWizard() {
    wizardOpen = false;
    notifyListeners();
  }

  Future<void> onProfileCreated(String name) async {
    wizardOpen = false;
    await refreshPersonas();
    selectedPersona = name;
    final s = createSession(persona: name);
    sessions = [s, ...sessions];
    activeSessionId = s.id;
    currentPage = AppPage.profile;
    await _persist();
    notifyListeners();
  }

  void markModelConfigured() {
    if (!modelConfigured) {
      modelConfigured = true;
      notifyListeners();
    }
  }

  Future<void> selectPersona(String persona) async {
    selectedPersona = persona;
    final s = createSession(persona: persona.isEmpty ? null : persona);
    sessions = [s, ...sessions];
    activeSessionId = s.id;
    currentPage = AppPage.chat;
    await _persist();
    notifyListeners();
  }

  Future<void> newChat() async {
    final s = createSession(
      persona: selectedPersona.isEmpty ? null : selectedPersona,
    );
    sessions = [s, ...sessions];
    activeSessionId = s.id;
    currentPage = AppPage.chat;
    await _persist();
    notifyListeners();
  }

  Future<void> selectSession(String id) async {
    activeSessionId = id;
    final s = sessions.cast<ChatSession?>().firstWhere(
      (x) => x?.id == id,
      orElse: () => null,
    );
    if (s != null) selectedPersona = s.persona ?? '';
    currentPage = AppPage.chat;
    await _store.saveActiveId(id);
    notifyListeners();
  }

  Future<void> renameSession(String id, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    for (final s in sessions) {
      if (s.id == id) s.title = t;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> archiveSession(String id, bool archived) async {
    for (final s in sessions) {
      if (s.id == id) s.archived = archived;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    final s = sessions.cast<ChatSession?>().firstWhere(
      (x) => x?.id == id,
      orElse: () => null,
    );
    if (s?.sessionKey != null && api != null) {
      try {
        await api!.deleteRemoteSession(s!.sessionKey!);
      } catch (_) {}
    }
    sessions = sessions.where((x) => x.id != id).toList();
    if (activeSessionId == id) {
      if (sessions.isEmpty) {
        final ns = createSession(
          persona: selectedPersona.isEmpty ? null : selectedPersona,
        );
        sessions = [ns];
        activeSessionId = ns.id;
      } else {
        activeSessionId = sessions.first.id;
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> sendChat(String text) async {
    final a = api;
    final session = activeSession;
    if (a == null || session == null || stream != null) return;
    final msg = text.trim();
    if (msg.isEmpty) return;

    session.messages.add(ChatMessage(role: 'user', content: msg));
    if (session.title == '新对话') session.title = titleFromMessage(msg);
    stream = StreamState();
    notifyListeners();
    await _persist();

    final turnId = generateSessionId();
    session.pendingTurnId = turnId;

    _cancelStream = a.streamChat(
      message: msg,
      sessionId: session.id,
      persona: session.persona ?? selectedPersona,
      turnId: turnId,
      onToken: (c) {
        stream?.content = '${stream?.content ?? ''}$c';
        notifyListeners();
      },
      onThinking: (c) {
        stream?.thinking = '${stream?.thinking ?? ''}$c';
        notifyListeners();
      },
      onActivity: (s) {
        stream?.activity = s;
        notifyListeners();
      },
      onDone: (key) {
        final content = stream?.content ?? '';
        final thinking = stream?.thinking;
        final activity = stream?.activity;
        session.messages.add(
          ChatMessage(
            role: 'assistant',
            content: content.isEmpty ? '（空回复）' : content,
            thinking: thinking,
            activity: activity,
          ),
        );
        if (key != null && key.isNotEmpty) session.sessionKey = key;
        session.pendingTurnId = null;
        stream = null;
        _cancelStream = null;
        _persist();
        notifyListeners();
      },
      onError: (err) {
        session.messages.add(
          ChatMessage(role: 'assistant', content: '请求失败：$err'),
        );
        session.pendingTurnId = null;
        stream = null;
        _cancelStream = null;
        _persist();
        notifyListeners();
      },
    );
  }

  Future<void> stopChat() async {
    final session = activeSession;
    final a = api;
    if (session != null && a != null) {
      try {
        await a.stopChat(session.id);
      } catch (_) {}
    }
    await _cancelStream?.call();
    if (stream != null) {
      final content = stream!.content;
      if (content.isNotEmpty && session != null) {
        session.messages.add(ChatMessage(role: 'assistant', content: content));
      }
      stream = null;
      _cancelStream = null;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> shutdown() async {
    await _cancelStream?.call();
    await launcher?.stop();
  }
}
