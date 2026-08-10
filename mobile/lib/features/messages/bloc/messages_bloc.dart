// ============================================================
// messages_bloc.dart — BLoC + Models + DataSource de Mensajes
// ============================================================
// Mensajes internos entre padre y docente (no tiempo real).
// A diferencia del Chat (Supabase Realtime), los mensajes son
// conversaciones tipo bandeja de entrada (estilo email escolar).
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────

class MessageModel {
  final int id;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String subject;
  final String body;
  final bool isRead;
  final DateTime sentAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.subject,
    required this.body,
    required this.isRead,
    required this.sentAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: int.parse(json['id'].toString()),
      senderId: sender['id'] != null ? int.parse(sender['id'].toString()) : 0,
      senderName:
          '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'.trim(),
      senderAvatar: sender['avatar'] as String?,
      subject: json['subject'] as String? ?? '(sin asunto)',
      body: json['body'] as String,
      isRead: json['isRead'] as bool? ?? false,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );
  }
}

class MessageThreadModel {
  final MessageModel original;
  final List<MessageModel> replies;

  const MessageThreadModel({required this.original, required this.replies});

  List<MessageModel> get all => [original, ...replies];
}

// ── DataSource ────────────────────────────────────────────

class MessagesDataSource {
  final ApiClient _client;
  MessagesDataSource(this._client);

  Future<List<MessageModel>> getInbox() async {
    final r = await _client.get('messages/inbox');
    // Backend devuelve {messages: [{id, isRead, message: {id, subject, body, sender,...}}], unreadCount}
    final data = r.data as Map<String, dynamic>;
    final list = data['messages'] as List<dynamic>? ?? [];
    return list.map((item) {
      final wrapper = item as Map<String, dynamic>;
      final msg = wrapper['message'] as Map<String, dynamic>;
      // Merge isRead del wrapper con los campos del mensaje
      return MessageModel.fromJson({...msg, 'isRead': wrapper['isRead']});
    }).toList();
  }

  Future<MessageThreadModel> getThread(int messageId) async {
    final r = await _client.get('messages/$messageId/thread');
    // Backend devuelve array cronológico: [mensaje_original, ...respuestas]
    final list = r.data as List<dynamic>;
    if (list.isEmpty) {
      throw Exception('Hilo de mensajes vacío');
    }
    return MessageThreadModel(
      original: MessageModel.fromJson(list.first as Map<String, dynamic>),
      replies: list.skip(1)
          .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> send({
    required int recipientId,
    required String subject,
    required String body,
    int? parentMessageId,
  }) async {
    await _client.post('messages', data: {
      'recipientId': recipientId,
      'subject': subject,
      'body': body,
      if (parentMessageId != null) 'parentMessageId': parentMessageId,
    });
  }

  Future<int> getUnreadCount() async {
    final r = await _client.get('messages/unread-count');
    return (r.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}

// ── Events ────────────────────────────────────────────────
sealed class MessagesEvent { const MessagesEvent(); }

final class LoadInboxEvent extends MessagesEvent { const LoadInboxEvent(); }

final class LoadThreadEvent extends MessagesEvent {
  final int messageId;
  const LoadThreadEvent(this.messageId);
}

final class SendMessageEvent extends MessagesEvent {
  final int recipientId;
  final String subject;
  final String body;
  final int? parentMessageId; // ID del mensaje original al que se responde
  const SendMessageEvent({
    required this.recipientId,
    required this.subject,
    required this.body,
    this.parentMessageId,
  });
}

// ── States ────────────────────────────────────────────────
sealed class MessagesState { const MessagesState(); }

final class MessagesInitial extends MessagesState { const MessagesInitial(); }
final class MessagesLoading extends MessagesState { const MessagesLoading(); }

final class InboxLoaded extends MessagesState {
  final List<MessageModel> messages;
  final int unreadCount;
  const InboxLoaded({required this.messages, required this.unreadCount});
}

final class ThreadLoaded extends MessagesState {
  final MessageThreadModel thread;
  const ThreadLoaded(this.thread);
}

final class MessageSent extends MessagesState { const MessageSent(); }

final class MessagesError extends MessagesState {
  final String message;
  const MessagesError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────
class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  final MessagesDataSource _ds;

  MessagesBloc(this._ds) : super(const MessagesInitial()) {
    on<LoadInboxEvent>(_onLoadInbox);
    on<LoadThreadEvent>(_onLoadThread);
    on<SendMessageEvent>(_onSend);
  }

  Future<void> _onLoadInbox(
    LoadInboxEvent e,
    Emitter<MessagesState> emit,
  ) async {
    emit(const MessagesLoading());
    try {
      final messages = await _ds.getInbox();
      final unreadCount = messages.where((m) => !m.isRead).length;
      emit(InboxLoaded(messages: messages, unreadCount: unreadCount));
    } catch (ex) {
      emit(MessagesError(ex.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadThread(
    LoadThreadEvent e,
    Emitter<MessagesState> emit,
  ) async {
    emit(const MessagesLoading());
    try {
      emit(ThreadLoaded(await _ds.getThread(e.messageId)));
    } catch (ex) {
      emit(MessagesError(ex.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onSend(
    SendMessageEvent e,
    Emitter<MessagesState> emit,
  ) async {
    emit(const MessagesLoading());
    try {
      await _ds.send(
        recipientId: e.recipientId,
        subject: e.subject,
        body: e.body,
        parentMessageId: e.parentMessageId,
      );
      // Si es respuesta a un hilo, recarga el hilo; si es nuevo mensaje, recarga inbox
      if (e.parentMessageId != null) {
        add(LoadThreadEvent(e.parentMessageId!));
      } else {
        emit(const MessageSent());
        add(const LoadInboxEvent());
      }
    } catch (ex) {
      emit(MessagesError(ex.toString().replaceFirst('Exception: ', '')));
    }
  }
}
