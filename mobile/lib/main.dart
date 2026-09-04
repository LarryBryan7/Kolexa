// ============================================================
// main.dart — Punto de entrada de la app Flutter
// ============================================================
// Inicializa dependencias, BLoC de auth y el router de go_router.
// También expone ApiClient al árbol de widgets via RepositoryProvider
// para que los BLoCs creados en navegación puedan accederlo.
// ============================================================

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/db/app_database.dart';
import 'core/services/push_notifications_service.dart';
import 'core/services/onboarding_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_sizes.dart';
import 'core/api/api_client.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/classroom/bloc/classroom_bloc.dart';
import 'features/classroom/data/repository/classroom_repository.dart';
import 'features/threads/data/inbox_sync_service.dart';
import 'features/threads/data/threads_local_store.dart';
import 'features/threads/data/threads_repository.dart';
import 'features/threads/ui/inbox_page.dart';
import 'features/threads/ui/new_message_page.dart';
import 'features/threads/ui/thread_page.dart';
import 'core/api/interceptors/auth_interceptor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase DEBE inicializarse antes de runApp: muchos widgets lo usan
  // en el primer frame (auth, home, banner de notificaciones).
  await Firebase.initializeApp();
  // OnboardingService cachea SharedPreferences ANTES de runApp para que
  // el router pueda decidir el initialLocation (welcome vs login) de forma
  // síncrona en el primer build.
  await OnboardingService.instance.initialize();
  runApp(const KolexaApp());

  // Push notifications se inicializa en background, SIN bloquear el primer
  // frame. En gama baja (ej. Samsung A10 / Exynos) crear el canal de
  // notificaciones, inicializar flutter_local_notifications y obtener el
  // token FCM puede tardar varios segundos. Al no hacer `await` aquí, el
  // splash nativo desaparece mucho más rápido.
  //
  // NOTA: en modo debug (flutter run) el arranque completo puede tardar
  // 10-20s+ por el JIT y el VM service de depuración — es overhead exclusivo
  // de debug, no ocurre en release (medido: 0.8-1.4s en Samsung A10 release).
  // No usar addPostFrameCallback ni Future.delayed aquí: no reducen el jank
  // de debug (confirmado con logcat) y solo restan margen en producción.
  unawaited(PushNotificationsService.instance.initialize());
}

class KolexaApp extends StatefulWidget {
  const KolexaApp({super.key});

  @override
  State<KolexaApp> createState() => _KolexaAppState();
}

class _KolexaAppState extends State<KolexaApp> {
  late final ApiClient _apiClient;
  late final AuthBloc _authBloc;
  late final ClassroomBloc _classroomBloc;
  late final StreamSubscription<AuthState> _authDbSub;

  // Notificación pendiente de procesar. Se guarda cuando la app se abre
  // desde una notificación (terminated) ANTES de que el router exista,
  // y se procesa en el primer frame cuando el router ya está listo.
  Map<String, dynamic>? _pendingNotification;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    final authDataSource = AuthRemoteDataSource(_apiClient);
    final authRepository = AuthRepository(authDataSource);
    _authBloc = AuthBloc(authRepository);
    // Aísla los datos locales (SQLite) entre cuentas del mismo dispositivo:
    // cada usuario autenticado tiene su propio archivo (ver
    // AppDatabase.openForUser), y al cerrar sesión se cierra esa conexión
    // y se limpian los caches en memoria de mensajería — así una cuenta
    // distinta que inicie sesión en el MISMO proceso nunca ve, ni por un
    // instante, hilos/mensajes/contactos de la cuenta anterior. Escuchar
    // el stream (no un BlocListener en el árbol) cubre los 3 caminos que
    // terminan en AuthAuthenticated/AuthUnauthenticated sin importar qué
    // pantalla esté activa: login interactivo, restauración de sesión en
    // frío (CheckAuthEvent, más abajo) y logout forzado por token expirado
    // (ver AuthInterceptor.onSessionExpired, que dispara el mismo
    // LogoutEvent que un logout manual).
    _authDbSub = _authBloc.stream.listen(_handleAuthStateChangeForLocalData);
    _authBloc.add(const CheckAuthEvent());
    AuthInterceptor.onSessionExpired = () => _authBloc.add(const LogoutEvent());
    _classroomBloc = ClassroomBloc(ClassroomRepository(_apiClient));

    // Navegación al tocar una notificación (nivel WhatsApp):
    // cuando el usuario toca una notificación, lo llevamos a la pantalla
    // correspondiente según el campo `screen` que envía el backend.
    PushNotificationsService.instance.onNotificationTap = _handleNotificationTap;

    // Resincroniza el token FCM con el backend sin necesitar un login nuevo:
    // se dispara tanto en el fetch inicial (sesión ya restaurada al abrir la
    // app) como en una rotación real de Firebase durante la sesión. Antes el
    // token solo se guardaba en el login, así que reinstalar la app o una
    // rotación normal de Firebase dejaba el push muerto en silencio.
    PushNotificationsService.instance.onTokenRefresh = authRepository.syncPushToken;
  }

  Future<void> _handleAuthStateChangeForLocalData(AuthState state) async {
    if (state is AuthAuthenticated) {
      await AppDatabase.instance.openForUser(state.user.id);
      // Arranca ya (no espera a que el usuario entre a la pestaña Chats) —
      // ver inbox_sync_service.dart.
      InboxSyncService.instance.start(_apiClient);
    } else if (state is AuthUnauthenticated) {
      InboxSyncService.instance.stop();
      InboxPage.clearCache();
      ThreadPage.clearCache();
      NewMessagePage.clearCache();
      await AppDatabase.instance.close();
    }
  }

  // Decide a dónde navegar cuando el usuario toca una notificación.
  // El backend envía `data['screen']` con el destino (ej: 'novedades').
  void _handleNotificationTap(Map<String, dynamic> data) {
    // Si el router aún no está inicializado (app abierta desde una
    // notificación en estado terminated), guardar la notificación y
    // procesarla en el primer frame.
    if (!AppRouter.isReady) {
      _pendingNotification = data;
      return;
    }
    _navigateToNotification(data);
  }

  void _navigateToNotification(Map<String, dynamic> data) {
    final screen = data['screen'];
    final studentName = data['studentName'];

    // Notificación de un mensaje: se abre aparte (ver
    // _openThreadFromNotification) — necesita esperar a que la sesión
    // esté resuelta antes de tocar el router, cosa que un simple `go()`
    // acá no puede garantizar.
    if (screen == 'thread') {
      final threadId = data['threadId'] as String?;
      if (threadId != null) _openThreadFromNotification(threadId);
      return;
    }

    // Las notificaciones de asistencia/fotos apuntan a 'novedades',
    // que es el tab principal del home. Navegamos al home y, si venimos
    // de una notificación de un alumno concreto, lo pasamos como parámetro
    // para que el home pueda seleccionarlo.
    if (screen == 'novedades') {
      final query = studentName != null ? '?studentName=$studentName' : '';
      AppRouter.router.go('${AppRouter.home}$query');
      return;
    }

    // Fallback: cualquier otra notificación lleva al home.
    AppRouter.router.go(AppRouter.home);
  }

  // Abre el hilo de una notificación de mensaje. Diseñado para que:
  //   1. No se vea el salto splash→home→chat: si la sesión todavía se
  //      está resolviendo (cold start recién abierto desde la
  //      notificación), esperamos ACÁ a que termine en vez de pedirle al
  //      router que navegue a home de una — eso era lo que antes lo
  //      rebotaba a /splash (el redirect de AppRouter no deja pasar a
  //      home hasta que AuthBloc resuelve) y perdía en el camino el pedido
  //      de pestaña, la causa real tanto del flash como del "back" que no
  //      caía en la bandeja.
  //   2. "Atrás" desde la conversación caiga siempre en la bandeja: se
  //      descarta cualquier pantalla que hubiera quedada empujada encima
  //      (popUntil) y se fuerza la pestaña Chats del home vía
  //      InboxSyncService.requestChatsTab — no por query param de ruta,
  //      que es precisamente lo que se perdía en el punto 1.
  //   3. El mensaje ya esté ahí al abrir, no recién al montarse
  //      ThreadPage: se precargan los mensajes del hilo (mismo motivo que
  //      InboxSyncService._prefetchThread, que solo corre con la app en
  //      primer plano — con la app en segundo plano/cerrada, que es el
  //      caso real de "tocar una notificación", el handler de background
  //      de Firebase no ejecuta nada de Dart, ver _firebaseBackgroundHandler).
  Future<void> _openThreadFromNotification(String threadId) async {
    var authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      authState = await _authBloc.stream.firstWhere(
        (s) => s is AuthAuthenticated || s is AuthUnauthenticated || s is AuthError,
      );
    }
    if (authState is! AuthAuthenticated) return; // no había sesión — nada que abrir

    final nav = AppRouter.router.routerDelegate.navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    if (AppRouter.router.routerDelegate.currentConfiguration.uri.path != AppRouter.home) {
      AppRouter.router.go(AppRouter.home);
    }
    InboxSyncService.instance.requestChatsTab();

    // Si es el PRIMER mensaje del hilo (nunca estuvo en la bandeja), el
    // cache local todavía no lo tiene — por eso el header salía genérico
    // ("Conversación", sin foto/rol) para conversaciones recién creadas.
    // refresh() trae la bandeja fresca de la red antes de leer el cache
    // (ya traga sus propios errores — sin red, sigue con lo que había).
    // Independiente de getMessages() de abajo, así que van en paralelo.
    await Future.wait([
      InboxSyncService.instance.refresh(),
      () async {
        try {
          final page = await ThreadsRepository(_apiClient).getMessages(threadId);
          ThreadPage.primeCache(threadId, page);
          ThreadsLocalStore.saveThread(threadId, page).catchError((e, st) {
            debugPrint('[main] saveThread (notificación) falló: $e\n$st');
          });
        } catch (e, st) {
          debugPrint('[main] getMessages (notificación) falló: $e\n$st');
          // ThreadPage igual los pide sola al montarse — solo se pierde el
          // "ya está todo ahí al instante" para esta apertura puntual.
        }
      }(),
    ]);
    List<ThreadSummary> threads = const [];
    try {
      threads = await ThreadsLocalStore.loadInbox();
    } catch (_) {
      // Sin dato local todavía — se abre igual con datos genéricos en vez
      // de no navegar a ningún lado.
    }
    ThreadSummary? match;
    for (final t in threads) {
      if (t.id == threadId) {
        match = t;
        break;
      }
    }
    if (!mounted) return;
    nav.push(MaterialPageRoute(
      builder: (_) => ThreadPage(
        threadId: threadId,
        title: match?.otherParticipant?.name ?? 'Conversación',
        avatarUrl: match?.otherParticipant?.avatar,
        online: match?.otherParticipant?.online ?? false,
        otherRole: match?.otherParticipant?.role,
        studentId: match?.studentId,
        studentName: match?.studentName,
      ),
    ));
  }

  @override
  void dispose() {
    _authDbSub.cancel();
    _authBloc.close();
    _classroomBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(_authBloc);

    // Si la app se abrió desde una notificación (terminated), el router
    // ya está listo ahora. Procesar la notificación pendiente en el primer
    // frame para navegar a la pantalla correcta.
    if (_pendingNotification != null) {
      final pending = _pendingNotification;
      _pendingNotification = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToNotification(pending!);
      });
    }

    return RepositoryProvider<ApiClient>.value(
      value: _apiClient,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<ClassroomBloc>.value(value: _classroomBloc),
        ],
        child: MaterialApp.router(
          title: 'Kolexa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: router,

          // Breakpoint de AppSizes: se evalúa acá porque `builder` es el
          // primer punto del árbol donde MediaQuery (y por lo tanto el
          // ancho real de pantalla) ya está disponible, antes de construir
          // cualquier pantalla. Se re-evalúa solo si el ancho cambia
          // (rotación, ventana redimensionada en desktop/web).
          builder: (context, child) {
            final width = MediaQuery.of(context).size.width;
            final sizes = width >= 400 ? AppSizes.medium : AppSizes.compact;
            return Theme(
              data: Theme.of(context).copyWith(extensions: [sizes]),
              child: child!,
            );
          },

          // Localización en español: DatePicker, TimePicker y otros
          // widgets de Material mostrarán textos en español
          locale: const Locale('es', 'PE'),
          supportedLocales: const [
            Locale('es', 'PE'), // español Perú
            Locale('en', 'US'), // inglés fallback
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}
