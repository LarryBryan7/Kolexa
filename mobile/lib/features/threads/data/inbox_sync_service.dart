// ============================================================
// inbox_sync_service.dart — refresco de bandeja en segundo plano
// ============================================================
// Las 3 variantes de home (docente/padre/director) solo montan InboxPage
// mientras la pestaña "Chats" está activa — al cambiar de pestaña se
// destruye por completo (no es un IndexedStack), y con ella su listener de
// PushNotificationsService y su observer de resume. Un push que llega
// mientras el usuario está en otra pestaña no tenía quién lo escuchara, así
// que la bandeja solo se veía al día recién al volver a entrar a Chats.
//
// Este servicio vive tanto como la sesión (arranca/para junto con
// AppDatabase.openForUser/close en main.dart), no como un widget, así que
// sigue escuchando pushes y el resume de la app sin importar qué pestaña
// esté activa: deja la bandeja (memoria + disco) ya fresca para cuando
// InboxPage se vuelva a montar, y expone el conteo de no-leídos para el
// badge del nav inferior. No reemplaza el refresco propio de InboxPage
// (que sigue actualizando su UI al instante si está montada) — es
// puramente aditivo para el caso que antes no tenía cobertura.
//
// Mismo problema, un nivel más abajo: un push de un hilo puntual solo traía
// el RESUMEN (bandeja) al día — la conversación en sí (ThreadPage) recién
// se buscaba cuando el usuario la abría, así que "casi todos los mensajes"
// tardaban el round-trip completo en aparecer aunque ya llevaran rato
// esperando en el backend. Por eso, además de refrescar la bandeja, este
// servicio también precarga los mensajes del hilo puntual que trae el push
// (`data['threadId']`) — no de TODOS los hilos en cada resume, que sería
// un fetch completo por conversación sin ninguna señal de que cambiaron.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, AppLifecycleState, WidgetsBindingObserver;

import '../../../core/api/api_client.dart';
import '../../../core/services/push_notifications_service.dart';
import '../ui/inbox_page.dart';
import '../ui/thread_page.dart';
import 'threads_local_store.dart';
import 'threads_repository.dart';

class InboxSyncService with WidgetsBindingObserver {
  InboxSyncService._();
  static final InboxSyncService instance = InboxSyncService._();

  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  // Se incrementa cada vez que `refresh()` deja la bandeja al día. Sirve
  // para el caso que `InboxPage.primeCache` por sí solo no cubre: una
  // InboxPage que sigue MONTADA debajo de otra pantalla en la misma
  // pestaña (ej. ThreadPage empujada encima al crear una conversación
  // nueva) nunca vuelve a correr `initState()` con un simple `pop()`, así
  // que jamás relee el cache recién actualizado por su cuenta. InboxPage
  // escucha este contador para refrescar su propio estado cuando sigue
  // viva pero no se remonta.
  final ValueNotifier<int> version = ValueNotifier(0);

  // "Abrir la pestaña Chats" pedido desde fuera (ver main.dart, al tocar
  // una notificación de mensaje) — se resuelve con o sin un Home ya vivo,
  // a diferencia de un query param de ruta: go_router puede perder ese
  // parámetro si el redirect por sesión-sin-resolver todavía rebota a
  // splash en el medio (esa era la causa real del flash y del "back" que
  // no caía en la bandeja). Consume-once: cada pedido lo agarra una sola
  // vez, la primera InboxPage/Home que lo consulte — initState() para un
  // montaje nuevo, el listener de abajo para uno que ya estaba vivo.
  int? _pendingChatsTab;
  final ValueNotifier<int> chatsTabRequests = ValueNotifier(0);

  void requestChatsTab() {
    _pendingChatsTab = 1;
    chatsTabRequests.value++;
  }

  int? consumeChatsTabRequest() {
    final v = _pendingChatsTab;
    _pendingChatsTab = null;
    return v;
  }

  ApiClient? _client;
  void Function(Map<String, dynamic> data)? _pushListener;

  /// Se llama una vez por sesión (ver main.dart, junto con
  /// `AppDatabase.instance.openForUser`) — arranca en cuanto se conoce la
  /// cuenta activa, sin esperar a que el usuario entre a Chats.
  void start(ApiClient client) {
    _client = client;
    _pushListener = (data) {
      if (data['screen'] != 'thread') return;
      refresh();
      final threadId = data['threadId'] as String?;
      if (threadId != null) _prefetchThread(threadId);
    };
    PushNotificationsService.instance.addDataRefreshListener(_pushListener!);
    WidgetsBinding.instance.addObserver(this);
    _seedFromDisk();
    refresh();
  }

  /// Se llama al cerrar sesión (ver main.dart, junto con
  /// `AppDatabase.instance.close()`/los `clearCache()` de mensajería).
  void stop() {
    final listener = _pushListener;
    if (listener != null) PushNotificationsService.instance.removeDataRefreshListener(listener);
    _pushListener = null;
    WidgetsBinding.instance.removeObserver(this);
    _client = null;
    unreadCount.value = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  // Conteo instantáneo desde disco al arrancar la sesión — mismo patrón
  // "disco primero, red confirma después" que ya usa InboxPage, para que el
  // badge no arranque en 0 mientras se espera el round-trip a São Paulo.
  Future<void> _seedFromDisk() async {
    try {
      final local = await ThreadsLocalStore.loadInbox();
      if (_client == null || local.isEmpty) return; // sesión cerrada mientras leía, o nada aún
      unreadCount.value = local.where((t) => t.unread).length;
    } catch (_) {
      // Sin dato local todavía (primera vez en el dispositivo) — refresh()
      // (llamado junto a este método) trae el conteo real de todos modos.
    }
  }

  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    try {
      final threads = await ThreadsRepository(client).getInbox();
      if (_client != client) return; // se cerró sesión mientras la red respondía
      InboxPage.primeCache(threads);
      ThreadsLocalStore.saveInbox(threads).catchError((e, st) {
        debugPrint('[InboxSyncService] saveInbox falló: $e\n$st');
      });
      unreadCount.value = threads.where((t) => t.unread).length;
      version.value++;
    } catch (e, st) {
      debugPrint('[InboxSyncService] refresh falló: $e\n$st');
    }
  }

  // Precarga los mensajes de UN hilo puntual (el que trae el push) para que
  // ThreadPage los encuentre ya en disco/memoria al abrirlo, en vez de
  // recién pedirlos en ese momento — mismo motivo que primeCache() de
  // InboxPage, pero a nivel de una conversación.
  Future<void> _prefetchThread(String threadId) async {
    final client = _client;
    if (client == null) return;
    try {
      final page = await ThreadsRepository(client).getMessages(threadId);
      if (_client != client) return; // se cerró sesión mientras la red respondía
      ThreadPage.primeCache(threadId, page);
      ThreadsLocalStore.saveThread(threadId, page).catchError((e, st) {
        debugPrint('[InboxSyncService] saveThread falló (hilo $threadId): $e\n$st');
      });
    } catch (e, st) {
      debugPrint('[InboxSyncService] prefetchThread falló (hilo $threadId): $e\n$st');
    }
  }
}
