class ChatAttachment {
  const ChatAttachment({required this.id, required this.name, required this.path});

  final String id;
  final String name;
  final String path;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'path': path};

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        path: '${j['path'] ?? ''}',
      );
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.thinking,
    this.activity,
    this.attachments,
  });

  final String role; // user | assistant
  String content;
  String? thinking;
  String? activity;
  /// Structured attachment refs (request/retry only; bubble shows user text).
  List<ChatAttachment>? attachments;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (thinking != null) 'thinking': thinking,
        if (activity != null) 'activity': activity,
        if (attachments != null && attachments!.isNotEmpty)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: '${j['role'] ?? 'assistant'}',
        content: '${j['content'] ?? ''}',
        thinking: j['thinking']?.toString(),
        activity: j['activity']?.toString(),
        attachments: (j['attachments'] as List?)
            ?.whereType<Map>()
            .map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    this.persona,
    int? created,
    this.sessionKey,
    this.pendingTurnId,
    this.archived = false,
  })  : messages = messages ?? <ChatMessage>[],
        created = created ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String title;
  List<ChatMessage> messages;
  String? persona;
  final int created;
  String? sessionKey;
  String? pendingTurnId;
  bool archived;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (persona != null) 'persona': persona,
        'created': created,
        if (sessionKey != null) 'sessionKey': sessionKey,
        if (pendingTurnId != null) 'pendingTurnId': pendingTurnId,
        'archived': archived,
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: '${j['id']}',
        title: '${j['title'] ?? '新对话'}',
        messages: (j['messages'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        persona: j['persona']?.toString(),
        created: (j['created'] as num?)?.toInt(),
        sessionKey: j['sessionKey']?.toString(),
        pendingTurnId: j['pendingTurnId']?.toString(),
        archived: j['archived'] == true,
      );
}

class StreamState {
  StreamState({
    this.content = '',
    this.thinking = '',
    this.activity = '',
    this.stillWorking,
  });

  String content;
  String thinking;
  String activity;
  String? stillWorking;
}

enum AppPage {
  dashboard,
  chat,
  trends,
  ideas,
  calendar,
  publish,
  breakdown,
  skills,
  outputs,
  accounts,
  profile,
}

extension AppPageLabel on AppPage {
  String get label => switch (this) {
        AppPage.dashboard => '工作台',
        AppPage.chat => '对话',
        AppPage.trends => '热点雷达',
        AppPage.ideas => '选题库',
        AppPage.calendar => '内容日历',
        AppPage.publish => '发布中心',
        AppPage.breakdown => '爆款拆解',
        AppPage.skills => '技能库',
        AppPage.outputs => '内容库',
        AppPage.accounts => '账号',
        AppPage.profile => '画像',
      };
}
