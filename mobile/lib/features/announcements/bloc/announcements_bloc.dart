// ============================================================
// announcements_bloc.dart — BLoC + Events + States de Comunicados
// ============================================================
// Módulo simple: events, states y bloc en un solo archivo.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/announcement_model.dart';
import '../../../../core/api/api_client.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DATA SOURCE (inline para este módulo simple)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AnnouncementsDataSource {
  final ApiClient _client;

  AnnouncementsDataSource(this._client);

  Future<AnnouncementFeedResponse> getFeed({int limit = 20, int offset = 0}) async {
    final response = await _client.get(
      'announcements/feed',
      queryParams: {'limit': limit.toString(), 'offset': offset.toString()},
    );
    return AnnouncementFeedResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> markAsRead(int announcementId) async {
    await _client.patch('announcements/$announcementId/read');
  }

  Future<void> markAllAsRead() async {
    await _client.patch('announcements/read-all');
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// EVENTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sealed class AnnouncementsEvent {
  const AnnouncementsEvent();
}

final class LoadAnnouncementsEvent extends AnnouncementsEvent {
  final bool forceRefresh;

  const LoadAnnouncementsEvent({this.forceRefresh = false});
}

final class MarkAsReadEvent extends AnnouncementsEvent {
  final int announcementId;

  const MarkAsReadEvent(this.announcementId);
}

final class MarkAllAsReadEvent extends AnnouncementsEvent {
  const MarkAllAsReadEvent();
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// STATES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sealed class AnnouncementsState {
  const AnnouncementsState();
}

final class AnnouncementsInitial extends AnnouncementsState {
  const AnnouncementsInitial();
}

final class AnnouncementsLoading extends AnnouncementsState {
  const AnnouncementsLoading();
}

final class AnnouncementsLoaded extends AnnouncementsState {
  final List<AnnouncementModel> announcements;
  final int unreadCount;

  const AnnouncementsLoaded({
    required this.announcements,
    required this.unreadCount,
  });

  // Separar fijados del resto para mostrar en secciones
  List<AnnouncementModel> get pinned =>
      announcements.where((a) => a.isPinned).toList();
  List<AnnouncementModel> get regular =>
      announcements.where((a) => !a.isPinned).toList();

  // Actualiza el estado de lectura de un comunicado en memoria
  // (sin necesidad de recargar todo el feed)
  AnnouncementsLoaded markRead(int announcementId) {
    final updated = announcements.map((a) {
      if (a.id == announcementId && !a.isRead) {
        return AnnouncementModel(
          id: a.id,
          title: a.title,
          content: a.content,
          authorName: a.authorName,
          authorAvatar: a.authorAvatar,
          publishedAt: a.publishedAt,
          isPinned: a.isPinned,
          isRead: true,
          readAt: DateTime.now(),
          attachmentCount: a.attachmentCount,
        );
      }
      return a;
    }).toList();

    return AnnouncementsLoaded(
      announcements: updated,
      unreadCount: unreadCount > 0 ? unreadCount - 1 : 0,
    );
  }

  // Marca todos como leídos en memoria
  AnnouncementsLoaded markAllRead() {
    final updated = announcements
        .map((a) => AnnouncementModel(
              id: a.id,
              title: a.title,
              content: a.content,
              authorName: a.authorName,
              authorAvatar: a.authorAvatar,
              publishedAt: a.publishedAt,
              isPinned: a.isPinned,
              isRead: true,
              readAt: a.readAt ?? DateTime.now(),
              attachmentCount: a.attachmentCount,
            ))
        .toList();

    return AnnouncementsLoaded(announcements: updated, unreadCount: 0);
  }
}

final class AnnouncementsError extends AnnouncementsState {
  final String message;

  const AnnouncementsError(this.message);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BLOC
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AnnouncementsBloc extends Bloc<AnnouncementsEvent, AnnouncementsState> {
  final AnnouncementsDataSource _dataSource;

  AnnouncementsBloc(this._dataSource) : super(const AnnouncementsInitial()) {
    on<LoadAnnouncementsEvent>(_onLoad);
    on<MarkAsReadEvent>(_onMarkAsRead);
    on<MarkAllAsReadEvent>(_onMarkAllAsRead);
  }

  Future<void> _onLoad(
    LoadAnnouncementsEvent event,
    Emitter<AnnouncementsState> emit,
  ) async {
    emit(const AnnouncementsLoading());
    try {
      final feed = await _dataSource.getFeed();
      emit(AnnouncementsLoaded(
        announcements: feed.announcements,
        unreadCount: feed.unreadCount,
      ));
    } catch (e) {
      emit(AnnouncementsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onMarkAsRead(
    MarkAsReadEvent event,
    Emitter<AnnouncementsState> emit,
  ) async {
    // Actualizar UI inmediatamente (optimistic update)
    // sin esperar la respuesta del backend
    if (state is AnnouncementsLoaded) {
      emit((state as AnnouncementsLoaded).markRead(event.announcementId));
    }

    // Notificar al backend en background (sin await en el UI)
    try {
      await _dataSource.markAsRead(event.announcementId);
    } catch (_) {
      // Si falla, el badge se sincronizará la próxima vez que cargue el feed
    }
  }

  Future<void> _onMarkAllAsRead(
    MarkAllAsReadEvent event,
    Emitter<AnnouncementsState> emit,
  ) async {
    if (state is AnnouncementsLoaded) {
      emit((state as AnnouncementsLoaded).markAllRead());
    }
    try {
      await _dataSource.markAllAsRead();
    } catch (_) {}
  }
}
