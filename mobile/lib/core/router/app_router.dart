// ============================================================
// app_router.dart — Configuración de rutas con go_router
// ============================================================
// go_router maneja la navegación de la app de forma declarativa.
// Define qué pantalla mostrar según el estado de autenticación
// y la ruta URL actual.
//
// Flujo de navegación:
//   App arranca → splash nativo cubre todo (preserve en main.dart)
//   AuthBloc resuelve sesión → remove() → login (según sesión) o home
//   Sin sesión: login directo — todos los roles entran con Google + código
//   de invitación, el rol se valida en el backend (ver AuthService.loginWithGoogle).
//
// En Flutter Web, las rutas aparecen en la URL del navegador.
// En móvil, son rutas internas para el deep linking.
//
// ¿Por qué go_router en lugar del Navigator tradicional?
//   - Navegación declarativa (la URL refleja el estado)
//   - Deep linking out-of-the-box
//   - Integración nativa con BLoC via refreshListenable
//   - Redirección global sin duplicar lógica en cada pantalla
// ============================================================

import 'dart:async'; // para StreamSubscription
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/home/ui/home_v2_page.dart';
import '../../features/home/ui/home_docente_page.dart';
import '../../features/home/ui/home_director_page.dart';
import '../../features/onboarding/ui/hijos_encontrados_page.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/classroom/ui/classroom_page.dart';
import '../../features/classroom/bloc/classroom_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── _fadePage ─────────────────────────────────────────────
// Transición de fade universal (sin detectar gama de dispositivo — ver
// plans/plan-animaciones-rendimiento.md §9: el tratamiento "gama baja"
// (fade puro, barato) se aplica a TODOS, en vez de construir toda la
// infraestructura de detección de tier para un beneficio marginal).
// Reemplaza el corte seco por defecto de Navigator/MaterialPage entre
// pantallas por algo suave, sin agregar dependencias nuevas.
//
// Respeta "Reduce Motion" del SO (MediaQuery.disableAnimationsOf):
// si está activo, no hay transición — el cambio es instantáneo.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, __, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

// ── AppRouter ─────────────────────────────────────────────
class AppRouter {
  // Rutas como constantes para evitar strings duplicados
  static const String login = '/login';
  static const String hijosEncontrados = '/hijos-encontrados';
  static const String home = '/home';
  static const String classroom = '/classroom';

  // Rutas del flujo público (sin sesión).
  static const Set<String> _publicFlow = {login};

  // Instancia del GoRouter — se crea una sola vez
  // 'late final' significa: inicialización diferida, no cambia después
  static late GoRouter _router;

  // Bandera que indica si el router ya fue inicializado. No podemos usar
  // `_router != null` porque es un campo `late` no-nullable (accederlo
  // antes de inicializar lanza una excepción, no devuelve null).
  static bool _ready = false;

  // Inicializar el router con el AuthBloc para el refreshListenable
  // Llamar desde main.dart ANTES de crear el MaterialApp
  static GoRouter createRouter(AuthBloc authBloc) {
    // _GoRouterRefreshStream convierte el Stream del BLoC en un ChangeNotifier
    // que go_router puede escuchar para re-evaluar las redirecciones
    final refreshStream = _GoRouterRefreshStream(authBloc.stream);

    _router = GoRouter(
      initialLocation: login,

      // refreshListenable: go_router re-evalúa el redirect cada vez
      // que el BLoC emite un nuevo estado.
      // Sin esto, el redirect solo se ejecuta una vez al arrancar.
      refreshListenable: refreshStream,

      // redirect: se llama ANTES de mostrar cada ruta.
      // Decide si redirigir según el estado de Auth.
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        final location = state.matchedLocation;

        // Mientras AuthBloc resuelve la sesión el splash nativo cubre todo
        // (preserve en main.dart), así que no hace falta redirigir a nada.
        if (authState is AuthInitial || authState is AuthLoading) {
          return null;
        }

        // Sesión resuelta: navegar al destino.
        if (authState is AuthAuthenticated) {
          if (_publicFlow.contains(location)) return home;
          return null;
        }

        if (authState is AuthUnauthenticated || authState is AuthError) {
          if (!_publicFlow.contains(location)) return login;
          return null;
        }

        return null;
      },

      routes: [
        GoRoute(
          path: login,
          pageBuilder: (_, state) => _fadePage(state, const LoginPage()),
        ),
        GoRoute(
          path: hijosEncontrados,
          pageBuilder: (_, state) =>
              _fadePage(state, HijosEncontradosPage(user: state.extra as UserModel)),
        ),
        GoRoute(
          path: home,
          pageBuilder: (context, state) {
            final authState = context.read<AuthBloc>().state;
            // Parámetro opcional que llega al tocar una notificación
            // de asistencia (se usa para preseleccionar al hijo).
            final studentName = state.uri.queryParameters['studentName'];
            Widget page;
            if (authState is AuthAuthenticated) {
              if (authState.user.hasRole('school_admin') ||
                  authState.user.hasRole('director')) {
                page = const HomeDirectorPage();
              } else if (authState.user.hasRole('teacher')) {
                page = const HomeDocentePage();
              } else {
                page = HomeV2Page(initialStudentName: studentName);
              }
            } else {
              page = HomeV2Page(initialStudentName: studentName);
            }
            return _fadePage(state, page);
          },
        ),
        // Ruta de callback deep link OAuth — redirige al home
        GoRoute(
          path: '/connected',
          redirect: (_, __) => home,
        ),
        GoRoute(
          path: '/teacher-connected',
          redirect: (_, __) => home,
        ),
        GoRoute(
          path: classroom,
          pageBuilder: (context, state) {
            final studentId = state.uri.queryParameters['studentId'] ?? '';
            final studentName = state.uri.queryParameters['studentName'] ?? 'Alumno';
            return _fadePage(state, BlocProvider.value(
              value: context.read<ClassroomBloc>()
                ..add(LoadClassroom(studentId)),
              child: ClassroomPage(studentId: studentId, studentName: studentName),
            ));
          },
          // Subrutas de módulos (Fase 2+):
          // routes: [
          //   GoRoute(path: 'attendance', builder: ...),
          //   GoRoute(path: 'homework', builder: ...),
          // ],
        ),
      ],

      // errorBuilder: página 404 cuando la ruta no existe
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Página no encontrada: ${state.uri}'),
        ),
      ),
    );

    _ready = true;
    return _router;
  }

  static GoRouter get router => _router;

  // Indica si el router ya fue inicializado (createRouter fue llamado).
  // Se usa para saber si podemos navegar programáticamente (ej: al tocar
  // una notificación cuando la app se abrió desde estado terminated).
  static bool get isReady => _ready;
}

// ── _GoRouterRefreshStream ────────────────────────────────
// Adaptador que convierte un Stream<AuthState> en un ChangeNotifier.
//
// go_router escucha ChangeNotifiers para saber cuándo re-evaluar
// las redirecciones. Pero nuestro BLoC emite un Stream, no un ChangeNotifier.
// Esta clase hace la traducción entre los dos.
//
// Cómo funciona:
//   1. Se suscribe al Stream del BLoC en el constructor
//   2. Cada vez que llega un nuevo estado, llama a notifyListeners()
//   3. go_router escucha eso y re-ejecuta el redirect()
class _GoRouterRefreshStream extends ChangeNotifier {
  // Guardamos la suscripción para poder cancelarla en dispose()
  late final StreamSubscription<dynamic> _subscription;

  _GoRouterRefreshStream(Stream<dynamic> stream) {
    // Suscribirse al Stream del BLoC
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(), // notificar a go_router en cada estado nuevo
        );
  }

  @override
  void dispose() {
    // IMPORTANTE: siempre cancelar la suscripción para evitar memory leaks
    _subscription.cancel();
    super.dispose();
  }
}
