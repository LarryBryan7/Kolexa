// ============================================================
// announcements_page.dart — Pantalla de Comunicados
// ============================================================
// Feed de comunicados del colegio y el aula.
// Los fijados (isPinned) aparecen arriba con fondo especial.
// Al abrir un comunicado se marca como leído automáticamente.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/cached_avatar.dart';
import '../bloc/announcements_bloc.dart';
import '../data/models/announcement_model.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  @override
  void initState() {
    super.initState();
    context.read<AnnouncementsBloc>().add(const LoadAnnouncementsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<AnnouncementsBloc, AnnouncementsState>(
          builder: (context, state) {
            final unread = state is AnnouncementsLoaded ? state.unreadCount : 0;
            return Row(
              children: [
                const Text('Comunicados'),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  // Badge con la cantidad de no leídos
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          // Botón "Marcar todos como leídos"
          BlocBuilder<AnnouncementsBloc, AnnouncementsState>(
            builder: (context, state) {
              if (state is AnnouncementsLoaded && state.unreadCount > 0) {
                return TextButton(
                  onPressed: () => context
                      .read<AnnouncementsBloc>()
                      .add(const MarkAllAsReadEvent()),
                  child: const Text('Leídos', style: TextStyle(color: Colors.white)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<AnnouncementsBloc, AnnouncementsState>(
        builder: (context, state) {
          if (state is AnnouncementsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AnnouncementsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context
                        .read<AnnouncementsBloc>()
                        .add(const LoadAnnouncementsEvent(forceRefresh: true)),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (state is AnnouncementsLoaded) {
            return RefreshIndicator(
              onRefresh: () async => context
                  .read<AnnouncementsBloc>()
                  .add(const LoadAnnouncementsEvent(forceRefresh: true)),
              child: state.announcements.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No hay comunicados aún',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // Sección de comunicados fijados
                        if (state.pinned.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Text(
                              'FIJADOS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ...state.pinned.map(
                            (a) => _AnnouncementTile(
                              announcement: a,
                              isPinned: true,
                            ),
                          ),
                          const Divider(height: 24),
                        ],

                        // Comunicados regulares
                        if (state.regular.isNotEmpty)
                          ...state.regular.map(
                            (a) => _AnnouncementTile(announcement: a),
                          ),
                      ],
                    ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── _AnnouncementTile ─────────────────────────────────────
// Un comunicado en la lista.
// Los no leídos tienen el título en negrita y un punto azul.
class _AnnouncementTile extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isPinned;

  const _AnnouncementTile({
    required this.announcement,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(announcement.publishedAt);

    return InkWell(
      onTap: () {
        // Marcar como leído al abrir
        if (!announcement.isRead) {
          context
              .read<AnnouncementsBloc>()
              .add(MarkAsReadEvent(announcement.id));
        }
        // Abrir detalle del comunicado
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<AnnouncementsBloc>(),
              child: _AnnouncementDetailPage(announcement: announcement),
            ),
          ),
        );
      },
      child: Container(
        color: isPinned
            ? const Color(0xFFFFFBEB) // fondo amarillo suave para fijados
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar del autor
            CircleAvatar(
              radius: 20,
              backgroundImage: announcement.authorAvatar != null
                  ? cachedAvatarProvider(announcement.authorAvatar!)
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: announcement.authorAvatar == null
                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Pin icon si está fijado
                      if (isPinned) ...[
                        const Icon(Icons.push_pin, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          announcement.authorName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Punto azul para los no leídos
                      if (!announcement.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6, top: 2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: TextStyle(
                            fontWeight: announcement.isRead
                                ? FontWeight.normal
                                : FontWeight.bold, // negrita si no leído
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcement.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (announcement.attachmentCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.attach_file,
                            size: 12, color: Colors.grey.shade500),
                        Text(
                          ' ${announcement.attachmentCount} adjunto(s)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Convierte una fecha a texto relativo: "hace 5 min", "ayer", etc.
  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return DateFormat('d MMM', 'es').format(date);
  }
}

// ── _AnnouncementDetailPage ───────────────────────────────
// Vista completa del comunicado al tocarlo
class _AnnouncementDetailPage extends StatelessWidget {
  final AnnouncementModel announcement;

  const _AnnouncementDetailPage({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: autor + fecha
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: announcement.authorAvatar != null
                      ? cachedAvatarProvider(announcement.authorAvatar!)
                      : null,
                  child: announcement.authorAvatar == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(announcement.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      DateFormat('EEEE d MMMM, HH:mm', 'es')
                          .format(announcement.publishedAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Título
            Text(
              announcement.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Contenido completo
            Text(
              announcement.content,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
