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
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/classroom/bloc/classroom_bloc.dart';
import 'features/classroom/data/repository/classroom_repository.dart';
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
    _authBloc = AuthBloc(authRepository)..add(const CheckAuthEvent());
    AuthInterceptor.onSessionExpired = () => _authBloc.add(const LogoutEvent());
    _classroomBloc = ClassroomBloc(ClassroomRepository(_apiClient));

    // Navegación al tocar una notificación (nivel WhatsApp):
    // cuando el usuario toca una notificación, lo llevamos a la pantalla
    // correspondiente según el campo `screen` que envía el backend.
    PushNotificationsService.instance.onNotificationTap = _handleNotificationTap;
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

  @override
  void dispose() {
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
