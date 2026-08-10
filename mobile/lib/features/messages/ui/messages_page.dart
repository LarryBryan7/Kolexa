// ============================================================
// messages_page.dart — Pantalla de Mensajes internos (bandeja)
// ============================================================
// Permite enviar y leer mensajes entre padre y docente.
// No es en tiempo real (eso es el Chat). Es como un correo
// interno del colegio con asunto y cuerpo completo.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/messages_bloc.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  @override
  void initState() {
    super.initState();
    context.read<MessagesBloc>().add(const LoadInboxEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<MessagesBloc, MessagesState>(
          builder: (context, state) {
            final unread = state is InboxLoaded ? state.unreadCount : 0;
            return Row(
              children: [
                const Text('Mensajes'),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit),
        label: const Text('Nuevo mensaje'),
        onPressed: () => _showComposeSheet(context),
      ),
      body: BlocBuilder<MessagesBloc, MessagesState>(
        builder: (context, state) {
          if (state is MessagesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MessagesError) {
            return Center(child: Text(state.message));
          }
          if (state is InboxLoaded) {
            if (state.messages.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Bandeja vacía', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final msg = state.messages[i];
                return _MessageTile(
                  message: msg,
                  onTap: () => _openThread(context, msg),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _openThread(BuildContext context, MessageModel msg) {
    context.read<MessagesBloc>().add(LoadThreadEvent(msg.id));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<MessagesBloc>(),
          child: _ThreadPage(originalMessage: msg),
        ),
      ),
    );
  }

  void _showComposeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<MessagesBloc>(),
        child: const _ComposeSheet(),
      ),
    );
  }
}

// ── Tile de mensaje en la bandeja ─────────────────────────────
class _MessageTile extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onTap;

  const _MessageTile({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !message.isRead;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnread
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Punto azul si no leído
              if (isUnread)
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 16),

              // Avatar del remitente
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                backgroundImage: message.senderAvatar != null
                    ? NetworkImage(message.senderAvatar!)
                    : null,
                child: message.senderAvatar == null
                    ? Text(
                        message.senderName.isNotEmpty
                            ? message.senderName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.senderName,
                            style: TextStyle(
                              fontWeight:
                                  isUnread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(message.sentAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isUnread
                                ? const Color(0xFF6366F1)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.subject,
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.body,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    return '${d.day}/${d.month}';
  }
}

// ── Página de hilo de mensajes ────────────────────────────────
class _ThreadPage extends StatefulWidget {
  final MessageModel originalMessage;

  const _ThreadPage({required this.originalMessage});

  @override
  State<_ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<_ThreadPage> {
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.originalMessage.subject)),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<MessagesBloc, MessagesState>(
              builder: (context, state) {
                if (state is MessagesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ThreadLoaded) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.thread.all.length,
                    itemBuilder: (context, i) {
                      final msg = state.thread.all[i];
                      return _ThreadBubble(message: msg, isFirst: i == 0);
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Input de respuesta
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 12, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu respuesta...',
                      border: InputBorder.none,
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF6366F1)),
                  onPressed: () {
                    if (_replyCtrl.text.trim().isEmpty) return;
                    context.read<MessagesBloc>().add(
                          SendMessageEvent(
                            recipientId: widget.originalMessage.senderId,
                            subject: 'Re: ${widget.originalMessage.subject}',
                            body: _replyCtrl.text.trim(),
                            parentMessageId: widget.originalMessage.id,
                          ),
                        );
                    _replyCtrl.clear();
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

class _ThreadBubble extends StatelessWidget {
  final MessageModel message;
  final bool isFirst;

  const _ThreadBubble({required this.message, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFirst ? const Color(0xFF6366F1).withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFirst
              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.senderName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${message.sentAt.day}/${message.sentAt.month} · '
                '${message.sentAt.hour.toString().padLeft(2, '0')}:'
                '${message.sentAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message.body, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Sheet: redactar nuevo mensaje ────────────────────────────
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  int? _recipientId;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nuevo mensaje',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // En producción: selector de destinatario con búsqueda
          // Por ahora un campo de texto para el ID
          TextField(
            decoration: const InputDecoration(
              labelText: 'Para (nombre del destinatario)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_search),
            ),
            onChanged: (_) {
              // TODO: implementar buscador de usuarios
            },
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Asunto *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Mensaje *',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 6,
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Enviar mensaje'),
              onPressed: () {
                if (_subjectCtrl.text.trim().isEmpty ||
                    _bodyCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Completa asunto y mensaje')),
                  );
                  return;
                }
                context.read<MessagesBloc>().add(
                      SendMessageEvent(
                        recipientId: _recipientId ?? 0,
                        subject: _subjectCtrl.text.trim(),
                        body: _bodyCtrl.text.trim(),
                      ),
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mensaje enviado')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
