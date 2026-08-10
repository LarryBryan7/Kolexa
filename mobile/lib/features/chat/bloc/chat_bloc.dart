// ============================================================
// chat_bloc.dart — BLoC + DataSource + Models del Chat
// ============================================================
// El chat es especial porque combina dos fuentes de datos:
//   1. REST API (NestJS) → para cargar historial y enviar mensajes
//   2. Supabase Realtime → para recibir mensajes nuevos en tiempo real
//
// Flujo de un mensaje recibido en tiempo real:
//   Otro usuario envía mensaje
//     → NestJS lo guarda en la DB (tabla chat_messages)
//       → Supabase detecta el INSERT en chat_messages
//         → Emite evento a todos los suscritos al canal
//           → supabase_flutter recibe el payload
//             → El BLoC emite NewMessageEvent
//               → AttendanceLoaded se actualiza con el nuevo mensaje
//                 → Flutter reconstruye la UI mostrando el mensaje
//
// Nota: supabase_flutter no está en el pubspec.yaml aún.
// Lo agregamos ahora: flutter pub add supabase_flutter
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────

class ConversationModel {
  final int id;
  final String type;    // 'private' | 'group'
  final String? name;  // nombre del grupo (null en privados)
  final List<ParticipantModel> participants;
  final ChatMessageModel? lastMessage;

  const ConversationModel({
    required this.id,
    required this.type,
    this.name,
    required this.participants,
    this.lastMessage,
  });

  // Para chats privados, el nombre es el del otro participante
  String displayName(int currentUserId) {
    if (type == 'group') return name ?? 'Grupo';
    final other = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
    return other.fullName;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'] as List<dynamic>? ?? [];
    return ConversationModel(
      id: int.parse(json['id'].toString()),
      type: json['type'] as String,
      name: json['name'] as String?,
      participants: (json['participants'] as List<dynamic>)
          .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastMessage: messages.isNotEmpty
          ? ChatMessageModel.fromJson(messages.first as Map<String, dynamic>)
          : null,
    );
  }
}

class ParticipantModel {
  final int userId;
  final String firstName;
  final String lastName;
  final String? avatar;

  const ParticipantModel({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  String get fullName => '$firstName $lastName';

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return ParticipantModel(
      userId: user['id'] as int,
      firstName: user['firstName'] as String,
      lastName: user['lastName'] as String,
      avatar: user['avatar'] as String?,
    );
  }
}

class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final DateTime sentAt;
  final bool isDeleted;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.sentAt,
    this.isDeleted = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessageModel(
      id: int.parse(json['id'].toString()),
      conversationId: int.parse(json['conversationId'].toString()),
      senderId: int.parse(json['senderId'].toString()),
      senderName: sender != null ? '${sender['firstName']}' : 'Usuario',
      senderAvatar: sender?['avatar'] as String?,
      content: (json['body'] ?? json['content'] ?? '') as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      isDeleted: json['deletedAt'] != null,
    );
  }
}

// ── DataSource ────────────────────────────────────────────

class ChatDataSource {
  final ApiClient _client;

  ChatDataSource(this._client);

  Future<List<ConversationModel>> getConversations() async {
    final response = await _client.get('chat/conversations');
    return (response.data as List<dynamic>)
        .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationModel> startPrivateChat(int recipientId) async {
    final response = await _client.post(
      'chat/conversations/private',
      data: {'recipientId': recipientId},
    );
    return ConversationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ChatMessageModel>> getMessages(
    int conversationId, {
    int limit = 50,
    int? before,
  }) async {
    final response = await _client.get(
      'chat/conversations/$conversationId/messages',
      queryParams: {
        'limit': limit.toString(),
        if (before != null) 'before': before.toString(),
      },
    );
    return (response.data as List<dynamic>)
        .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
        .toList()
        .reversed
        .toList(); // reversar para mostrar más viejos arriba
  }

  Future<ChatMessageModel> sendMessage(int conversationId, String content) async {
    final response = await _client.post(
      'chat/conversations/$conversationId/messages',
      data: {'content': content},
    );
    return ChatMessageModel.fromJson(response.data as Map<String, dynamic>);
  }
}

// ── Events ────────────────────────────────────────────────
sealed class ChatEvent {
  const ChatEvent();
}

// Cargar lista de conversaciones
final class LoadConversationsEvent extends ChatEvent {
  const LoadConversationsEvent();
}

// Abrir una conversación específica y cargar sus mensajes
final class OpenConversationEvent extends ChatEvent {
  final int conversationId;

  const OpenConversationEvent(this.conversationId);
}

// El usuario escribe y envía un mensaje
final class SendMessageEvent extends ChatEvent {
  final int conversationId;
  final String content;

  const SendMessageEvent({
    required this.conversationId,
    required this.content,
  });
}

// Llegó un nuevo mensaje en tiempo real (lo emite Supabase Realtime)
final class NewRealtimeMessageEvent extends ChatEvent {
  final ChatMessageModel message;

  const NewRealtimeMessageEvent(this.message);
}

// ── States ────────────────────────────────────────────────
sealed class ChatState {
  const ChatState();
}

final class ChatInitial extends ChatState {
  const ChatInitial();
}

final class ChatLoading extends ChatState {
  const ChatLoading();
}

// Lista de conversaciones (pantalla principal del chat)
final class ConversationsLoaded extends ChatState {
  final List<ConversationModel> conversations;

  const ConversationsLoaded(this.conversations);
}

// Dentro de una conversación: muestra los mensajes
final class MessagesLoaded extends ChatState {
  final int conversationId;
  final List<ChatMessageModel> messages;
  final bool isSending; // ¿se está enviando un mensaje?

  const MessagesLoaded({
    required this.conversationId,
    required this.messages,
    this.isSending = false,
  });

  // Agrega un nuevo mensaje al final de la lista (para Realtime)
  MessagesLoaded withNewMessage(ChatMessageModel message) {
    return MessagesLoaded(
      conversationId: conversationId,
      messages: [...messages, message],
    );
  }

  MessagesLoaded copyWith({bool? isSending}) {
    return MessagesLoaded(
      conversationId: conversationId,
      messages: messages,
      isSending: isSending ?? this.isSending,
    );
  }
}

final class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatDataSource _dataSource;

  ChatBloc(this._dataSource) : super(const ChatInitial()) {
    on<LoadConversationsEvent>(_onLoadConversations);
    on<OpenConversationEvent>(_onOpenConversation);
    on<SendMessageEvent>(_onSendMessage);
    on<NewRealtimeMessageEvent>(_onNewRealtimeMessage);
  }

  Future<void> _onLoadConversations(
    LoadConversationsEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    try {
      final conversations = await _dataSource.getConversations();
      emit(ConversationsLoaded(conversations));
    } catch (e) {
      emit(ChatError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onOpenConversation(
    OpenConversationEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    try {
      final messages = await _dataSource.getMessages(event.conversationId);
      emit(MessagesLoaded(
        conversationId: event.conversationId,
        messages: messages,
      ));
    } catch (e) {
      emit(ChatError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! MessagesLoaded) return;
    final current = state as MessagesLoaded;

    // Mostrar indicator de envío
    emit(current.copyWith(isSending: true));

    try {
      final message = await _dataSource.sendMessage(
        event.conversationId,
        event.content,
      );
      // Agregar el mensaje enviado a la lista
      emit(current.withNewMessage(message));
    } catch (e) {
      emit(current.copyWith(isSending: false));
    }
  }

  void _onNewRealtimeMessage(
    NewRealtimeMessageEvent event,
    Emitter<ChatState> emit,
  ) {
    // Solo procesar si estamos viendo esa conversación
    if (state is MessagesLoaded) {
      final current = state as MessagesLoaded;
      if (current.conversationId == event.message.conversationId) {
        emit(current.withNewMessage(event.message));
      }
    }
  }
}
