// ============================================================
// threads_repository.dart — Mensajería 1:1 (padre ↔ docente ↔ director)
// ============================================================
// Consume el backend /inbox y /threads. El backend ya valida que solo se
// pueda escribir a alguien con quien se comparte un alumno (o al director);
// acá no se repite esa lógica — se confía en lo que devuelve /threads/contacts.
// ============================================================

import '../../../core/api/api_client.dart';

class MentionCandidate {
  final String id;
  // 'homework' (modelo institucional) o 'gc-coursework' (Google Classroom).
  // Determina qué namespace usar en el markup y qué pasa al tocar la mención.
  final String type;
  final String title;
  final DateTime? dueDate;
  final String courseName;

  const MentionCandidate({
    required this.id,
    required this.type,
    required this.title,
    required this.dueDate,
    required this.courseName,
  });

  factory MentionCandidate.fromJson(Map<String, dynamic> json) => MentionCandidate(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
        courseName: json['courseName'] as String,
      );
}

class ThreadStudentRef {
  final String id;
  final String name;
  const ThreadStudentRef({required this.id, required this.name});

  factory ThreadStudentRef.fromJson(Map<String, dynamic> json) =>
      ThreadStudentRef(id: json['id'] as String, name: json['name'] as String);
}

class Contact {
  final String userId;
  final String name;
  final String? avatar;
  final String role;
  final List<ThreadStudentRef> students;

  const Contact({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.role,
    required this.students,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      userId: json['userId'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      role: json['role'] as String,
      students: (json['students'] as List<dynamic>? ?? [])
          .map((s) => ThreadStudentRef.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ThreadPreview {
  final String body;
  final String senderId;
  final DateTime sentAt;
  // Doble check en la bandeja: solo importa cuando `senderId` soy yo — ver
  // ThreadsService.getInbox (misma señal que otherLastReadAt/otherLastActiveAt
  // en el detalle del chat: leyó el hilo, o estuvo online después del envío).
  final bool delivered;
  const ThreadPreview({
    required this.body,
    required this.senderId,
    required this.sentAt,
    this.delivered = false,
  });

  factory ThreadPreview.fromJson(Map<String, dynamic> json) => ThreadPreview(
        body: json['body'] as String,
        senderId: json['senderId'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
        delivered: json['delivered'] as bool? ?? false,
      );
}

class ThreadOtherParticipant {
  final String id;
  final String name;
  final String? avatar;
  final bool online;
  const ThreadOtherParticipant({
    required this.id,
    required this.name,
    this.avatar,
    this.online = false,
  });

  factory ThreadOtherParticipant.fromJson(Map<String, dynamic> json) => ThreadOtherParticipant(
        id: json['id'] as String,
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
        online: json['online'] as bool? ?? false,
      );
}

class ThreadSummary {
  final String id;
  final String kind;
  final String? subject;
  final String? studentId;
  final String? studentName;
  final String priority;
  final DateTime lastMessageAt;
  final bool unread;
  final int unreadCount;
  final bool muted;
  final ThreadOtherParticipant? otherParticipant;
  final ThreadPreview? lastMessage;

  const ThreadSummary({
    required this.id,
    required this.kind,
    this.subject,
    this.studentId,
    this.studentName,
    required this.priority,
    required this.lastMessageAt,
    required this.unread,
    required this.unreadCount,
    required this.muted,
    this.otherParticipant,
    this.lastMessage,
  });

  factory ThreadSummary.fromJson(Map<String, dynamic> json) {
    return ThreadSummary(
      id: json['id'] as String,
      kind: json['kind'] as String,
      subject: json['subject'] as String?,
      studentId: json['studentId'] as String?,
      studentName: json['studentName'] as String?,
      priority: json['priority'] as String,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      unread: json['unread'] as bool,
      unreadCount: json['unreadCount'] as int? ?? 0,
      muted: json['muted'] as bool,
      otherParticipant: json['otherParticipant'] != null
          ? ThreadOtherParticipant.fromJson(json['otherParticipant'] as Map<String, dynamic>)
          : null,
      lastMessage: json['lastMessage'] != null
          ? ThreadPreview.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ThreadMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime sentAt;
  // Solo para mensajes propios armados en el cliente antes de que el
  // backend confirme el envío (ver ThreadPage._send) — nunca vienen del
  // backend, por eso no están en fromJson.
  final bool isPending;
  final bool isFailed;

  const ThreadMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.sentAt,
    this.isPending = false,
    this.isFailed = false,
  });

  factory ThreadMessage.fromJson(Map<String, dynamic> json) => ThreadMessage(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        body: json['body'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
      );

  ThreadMessage copyWith({bool? isPending, bool? isFailed}) => ThreadMessage(
        id: id,
        senderId: senderId,
        senderName: senderName,
        body: body,
        sentAt: sentAt,
        isPending: isPending ?? this.isPending,
        isFailed: isFailed ?? this.isFailed,
      );
}

// Resultado de GET .../messages: los mensajes + dos señales del OTRO
// participante para el doble check (comparando contra el sentAt de cada
// mensaje propio): `otherLastReadAt` (leyó este hilo) y
// `otherLastActiveAt` (estuvo online/con conexión, aunque no haya abierto
// este hilo puntual — mismo dato que el punto verde/gris de presencia).
class ThreadMessagesPage {
  final List<ThreadMessage> messages;
  final DateTime? otherLastReadAt;
  final DateTime? otherLastActiveAt;
  const ThreadMessagesPage({
    required this.messages,
    required this.otherLastReadAt,
    required this.otherLastActiveAt,
  });
}

class ThreadsRepository {
  final ApiClient _client;
  ThreadsRepository(this._client);

  Future<List<ThreadSummary>> getInbox() async {
    final r = await _client.get('inbox');
    return (r.data as List<dynamic>)
        .map((e) => ThreadSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final r = await _client.get('inbox/unread-count');
    return r.data as int;
  }

  Future<List<Contact>> getContacts() async {
    final r = await _client.get('threads/contacts');
    return (r.data as List<dynamic>).map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> openThread({
    required String recipientId,
    String? studentId,
    String? subject,
    required String firstMessageBody,
  }) async {
    final r = await _client.post('threads', data: {
      'recipientId': int.parse(recipientId),
      if (studentId != null) 'studentId': int.parse(studentId),
      if (subject != null) 'subject': subject,
      'firstMessageBody': firstMessageBody,
    });
    return (r.data as Map<String, dynamic>)['threadId'] as String;
  }

  // `before`: id del mensaje más antiguo ya cargado, para pedir la página
  // anterior. Sin él, trae los más recientes.
  Future<ThreadMessagesPage> getMessages(String threadId, {String? before}) async {
    final r = await _client.get(
      'threads/$threadId/messages',
      queryParams: before != null ? {'before': before} : null,
    );
    final data = r.data as Map<String, dynamic>;
    final otherLastReadAt = data['otherLastReadAt'] as String?;
    final otherLastActiveAt = data['otherLastActiveAt'] as String?;
    return ThreadMessagesPage(
      messages: (data['messages'] as List<dynamic>)
          .map((e) => ThreadMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      otherLastReadAt: otherLastReadAt != null ? DateTime.parse(otherLastReadAt) : null,
      otherLastActiveAt: otherLastActiveAt != null ? DateTime.parse(otherLastActiveAt) : null,
    );
  }

  Future<void> sendMessage(String threadId, String body) async {
    await _client.post('threads/$threadId/messages', data: {'body': body});
  }

  // Autocompletado del "@" en el compositor: tareas del aula del alumno de
  // este hilo. El backend ya filtra por permisos, acá solo se pasa el texto.
  Future<List<MentionCandidate>> searchMentions(String threadId, String query) async {
    final r = await _client.get('threads/$threadId/mentions', queryParams: {'q': query});
    return (r.data as List<dynamic>)
        .map((e) => MentionCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // El mensaje solo guarda id + título de la tarea de Classroom mencionada;
  // el link externo se resuelve al tocarla (validado por participación en
  // el hilo, no por el id de la tarea a secas).
  Future<String?> getClassroomTaskLink(String threadId, String refId) async {
    final r = await _client.get('threads/$threadId/mentions/gc-coursework/$refId');
    return (r.data as Map<String, dynamic>)['alternateLink'] as String?;
  }

  Future<void> markRead(String threadId) async {
    await _client.patch('threads/$threadId/read');
  }

  Future<void> setMuted(String threadId, bool muted) async {
    await _client.patch('threads/$threadId/mute', data: {'muted': muted});
  }
}
