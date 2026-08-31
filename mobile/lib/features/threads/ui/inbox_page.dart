// ============================================================
// inbox_page.dart — "Chats": la bandeja de mensajería
// ============================================================
// Se embebe como pestaña dentro del home (igual que PerfilTab), no tiene
// Scaffold propio. Una sola lista, sin pestañas: si hay que elegir pestaña
// para saber qué urge, la bandeja falló — ver auditoría de mensajería.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/push_notifications_service.dart';
import '../data/threads_repository.dart';
import 'new_message_page.dart';
import 'thread_page.dart';

const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  // Cache en memoria a nivel de clase: sobrevive a que esta pantalla se
  // destruya y se vuelva a crear (ej. al cambiar de pestaña y volver), así
  // que reabrir Chats muestra la última lista conocida al instante, sin
  // loader — se refresca sola en segundo plano.
  static List<ThreadSummary>? _cachedThreads;

  List<ThreadSummary>? _threads;
  bool _loadingFirstTime = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _threads = _cachedThreads;
    _refresh(showErrorIfEmpty: true);
    PushNotificationsService.instance.addDataRefreshListener(_handleDataRefresh);
  }

  @override
  void dispose() {
    PushNotificationsService.instance.removeDataRefreshListener(_handleDataRefresh);
    super.dispose();
  }

  // Llega un mensaje nuevo en cualquier conversación: la bandeja se
  // refresca sola (nuevo orden, preview, punto de no-leído) sin que haga
  // falta salir y volver a entrar a la pestaña.
  void _handleDataRefresh(Map<String, dynamic> data) {
    if (!mounted || data['screen'] != 'thread') return;
    _refresh();
  }

  // Refresco silencioso: nunca borra `_threads` antes de tener el
  // resultado nuevo, así la lista ya cargada se queda visible en pantalla
  // mientras se pide de nuevo (a diferencia de un FutureBuilder, que
  // vuelve a mostrar el loader cada vez que se reemplaza el Future). El
  // spinner de pantalla completa solo aparece si de verdad no hay nada
  // que mostrar todavía.
  Future<void> _refresh({bool showErrorIfEmpty = false}) async {
    if (_threads == null) setState(() => _loadingFirstTime = true);
    try {
      final repo = ThreadsRepository(context.read<ApiClient>());
      final threads = await repo.getInbox();
      _cachedThreads = threads;
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _error = null;
        _loadingFirstTime = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFirstTime = false);
      // Un refresh silencioso que falla no debe tapar la lista ya cargada
      // con una pantalla de error — solo se muestra si no hay nada.
      if (showErrorIfEmpty && _threads == null) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _onRefresh() => _refresh(showErrorIfEmpty: true);

  Future<void> _openNewMessage() async {
    final opened = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewMessagePage()),
    );
    if (opened == true) await _onRefresh();
  }

  Future<void> _openThread(ThreadSummary t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadPage(
          threadId: t.id,
          title: t.otherParticipant?.name ?? 'Conversación',
          studentId: t.studentId,
          studentName: t.studentName,
        ),
      ),
    );
    await _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text('Chats',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: _kTextDark)),
              ),
              IconButton(
                onPressed: _openNewMessage,
                icon: const Icon(Icons.add_circle, color: _kPrimary, size: 28),
                tooltip: 'Nuevo mensaje',
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: _kPrimary,
            onRefresh: _onRefresh,
            child: Builder(builder: (context) {
              if (_threads == null) {
                if (_loadingFirstTime) {
                  return const Center(child: CircularProgressIndicator(color: _kPrimary));
                }
                if (_error != null) {
                  return _ErrorState(onRetry: _onRefresh);
                }
              }
              final threads = _threads ?? [];
              if (threads.isEmpty) {
                return _EmptyState(onNewMessage: _openNewMessage);
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: threads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ThreadRow(
                  thread: threads[i],
                  onTap: () => _openThread(threads[i]),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final ThreadSummary thread;
  final VoidCallback onTap;
  const _ThreadRow({required this.thread, required this.onTap});

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isEmpty) return '?';
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    final diff = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff < 7) return days[dt.weekday - 1];
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final name = thread.otherParticipant?.name ?? 'Colegio';
    return Material(
      color: thread.unread ? _kPrimaryLt : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _kPrimaryLt,
                backgroundImage: thread.otherParticipant?.avatar != null
                    ? NetworkImage(thread.otherParticipant!.avatar!)
                    : null,
                child: thread.otherParticipant?.avatar == null
                    ? Text(_initials(name),
                        style: const TextStyle(
                            color: _kPrimary, fontWeight: FontWeight.w700, fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: thread.unread ? FontWeight.w800 : FontWeight.w600,
                                  color: _kTextDark)),
                        ),
                        const SizedBox(width: 8),
                        Text(_timeLabel(thread.lastMessageAt),
                            style: const TextStyle(fontSize: 11, color: _kTextGray)),
                      ],
                    ),
                    if (thread.studentName != null) ...[
                      const SizedBox(height: 2),
                      Text('Sobre ${thread.studentName}',
                          style: const TextStyle(
                              fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      thread.lastMessage?.body ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: thread.unread ? _kTextDark : _kTextGray,
                        fontWeight: thread.unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (thread.unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewMessage;
  const _EmptyState({required this.onNewMessage});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 40, color: _kTextGray),
                  const SizedBox(height: 12),
                  const Text('Sin conversaciones todavía',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _kTextDark)),
                  const SizedBox(height: 6),
                  const Text(
                    'Escríbele al docente o al colegio cuando lo necesites.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _kTextGray),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: onNewMessage,
                    icon: const Icon(Icons.add, color: _kPrimary),
                    label: const Text('Nuevo mensaje', style: TextStyle(color: _kPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron cargar tus chats',
                    style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
