// ============================================================
// announcement_model.dart — Modelo de Comunicados
// ============================================================

class AnnouncementModel {
  final int id;
  final String title;
  final String content;
  final String authorName;
  final String? authorAvatar;
  final DateTime publishedAt;
  final bool isPinned;    // comunicado fijado en la parte superior
  final bool isRead;      // ¿este usuario ya lo leyó?
  final DateTime? readAt; // cuándo lo leyó
  final int attachmentCount;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    this.authorAvatar,
    required this.publishedAt,
    required this.isPinned,
    required this.isRead,
    this.readAt,
    required this.attachmentCount,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>;
    // readRecords es una lista de 0 o 1 elemento (el registro de lectura del usuario actual)
    final readRecords = json['readRecords'] as List<dynamic>? ?? [];
    final readRecord =
        readRecords.isNotEmpty ? readRecords.first as Map<String, dynamic> : null;
    final countMap = json['_count'] as Map<String, dynamic>? ?? {};

    return AnnouncementModel(
      id: int.parse(json['id'].toString()),
      title: json['title'] as String,
      content: json['content'] as String,
      authorName: '${author['firstName']} ${author['lastName']}',
      authorAvatar: author['avatar'] as String?,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      isRead: readRecord?['isRead'] as bool? ?? false,
      readAt: readRecord?['readAt'] != null
          ? DateTime.parse(readRecord!['readAt'] as String)
          : null,
      attachmentCount: countMap['attachments'] as int? ?? 0,
    );
  }
}

// Respuesta del endpoint GET /announcements/feed
class AnnouncementFeedResponse {
  final List<AnnouncementModel> announcements;
  final int unreadCount; // para el badge de notificaciones

  const AnnouncementFeedResponse({
    required this.announcements,
    required this.unreadCount,
  });

  factory AnnouncementFeedResponse.fromJson(Map<String, dynamic> json) {
    return AnnouncementFeedResponse(
      announcements: (json['announcements'] as List<dynamic>)
          .map((a) => AnnouncementModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unreadCount'] as int,
    );
  }
}
