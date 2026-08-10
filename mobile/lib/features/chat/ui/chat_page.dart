// ============================================================
// chat_page.dart — Pantalla de Chat en tiempo real
// ============================================================
// Dos pantallas:
//   ConversationsPage  → lista de chats (como la pantalla principal de WhatsApp)
//   ChatRoomPage       → mensajes de una conversación específica
//
// Para el tiempo real, usamos supabase_flutter.
// La suscripción a cambios en tiempo real se hace en el initState
// de ChatRoomPage y se cancela en dispose().
//
// IMPORTANTE: Para activar Supabase Realtime en la tabla chat_messages,
// debes ir a Supabase Dashboard → Database → Replication y habilitar
// la tabla 'chat_messages' para INSERT events.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/chat_bloc.dart';

// ── ConversationsPage ─────────────────────────────────────
// Lista de conversaciones del usuario
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(const LoadConversationsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ConversationsLoaded) {
            if (state.conversations.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No tienes conversaciones aún',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: state.conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final conv = state.conversations[index];
                return _ConversationTile(conversation: conv);
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// Tile de conversación en la lista
class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final lastMsg = conversation.lastMessage;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          conversation.displayName(0)[0].toUpperCase(), // TODO: pasar currentUserId
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        conversation.displayName(0),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: lastMsg != null
          ? Text(
              lastMsg.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            )
          : const Text(
              'Sin mensajes aún',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
      trailing: lastMsg != null
          ? Text(
              _formatTime(lastMsg.sentAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            )
          : null,
      onTap: () {
        // Abrir la sala de chat
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<ChatBloc>()
                ..add(OpenConversationEvent(conversation.id)),
              child: ChatRoomPage(
                conversationId: conversation.id,
                title: conversation.displayName(0),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day) return DateFormat('HH:mm').format(time);
    if (time.day == now.day - 1) return 'Ayer';
    return DateFormat('d/M').format(time);
  }
}

// ── ChatRoomPage ──────────────────────────────────────────
// Pantalla de mensajes de una conversación específica
class ChatRoomPage extends StatefulWidget {
  final int conversationId;
  final String title;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // TODO Fase 3: suscribir a Supabase Realtime aquí
  // final _supabaseClient = Supabase.instance.client;
  // late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    // _setupRealtimeSubscription(); // activar cuando se configure Supabase
  }

  // Supabase Realtime — escuchar mensajes nuevos en tiempo real
  // void _setupRealtimeSubscription() {
  //   _channel = _supabaseClient
  //       .channel('chat:${widget.conversationId}')
  //       .onPostgresChanges(
  //         event: PostgresChangeEvent.insert,
  //         schema: 'public',
  //         table: 'chat_messages',
  //         filter: PostgresChangeFilter(
  //           type: PostgresChangeFilterType.eq,
  //           column: 'conversation_id',
  //           value: widget.conversationId,
  //         ),
  //         callback: (payload) {
  //           // Cuando llega un mensaje nuevo, actualizar el BLoC
  //           final message = ChatMessageModel.fromJson(
  //             payload.newRecord as Map<String, dynamic>,
  //           );
  //           context.read<ChatBloc>().add(NewRealtimeMessageEvent(message));
  //           _scrollToBottom();
  //         },
  //       )
  //       .subscribe();
  // }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // _channel.unsubscribe(); // cancelar suscripción Realtime
    super.dispose();
  }

  void _scrollToBottom() {
    // Desplazar al final de la lista (mensaje más reciente)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<ChatBloc>().add(
          SendMessageEvent(
            conversationId: widget.conversationId,
            content: content,
          ),
        );

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          // ── Lista de mensajes ─────────────────────────
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is MessagesLoaded) {
                  if (state.messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Di "Hola" para empezar la conversación',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  // Hacer scroll al final cuando llegan nuevos mensajes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      // TODO: reemplazar 0 con el ID del usuario actual
                      final isMe = message.senderId == 0;
                      return _MessageBubble(
                        message: message,
                        isMe: isMe,
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // ── Campo de texto + botón enviar ─────────────
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón enviar
                BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, state) {
                    final isSending =
                        state is MessagesLoaded && state.isSending;
                    return IconButton(
                      onPressed: isSending ? null : _sendMessage,
                      icon: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MessageBubble ────────────────────────────────────────
// Burbuja de mensaje al estilo WhatsApp.
// Los mensajes propios van a la derecha (azul).
// Los mensajes del otro van a la izquierda (gris).
class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe; // ¿este mensaje lo envió el usuario actual?

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
          // Las burbujas no ocupan más del 75% del ancho de la pantalla
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            // La esquina que apunta al hablante es más pequeña
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nombre del remitente (solo en grupos o en mensajes ajenos)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            // Contenido del mensaje
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            // Hora del mensaje
            Text(
              DateFormat('HH:mm').format(message.sentAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white60 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
