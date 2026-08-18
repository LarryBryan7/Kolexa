// ============================================================
// app_router.dart — Configuración de rutas con go_router
// ============================================================
// go_router maneja la navegación de la app de forma declarativa.
// Define qué pantalla mostrar según el estado de autenticación
// y la ruta URL actual.
//
// Flujo de navegación:
//   App arranca → splash nativo cubre todo (preserve en main.dart)
//   AuthBloc resuelve sesión → remove() → welcome/login (según sesión) o home
//   Sin sesión: welcome → (crear cuenta) role-selection, o (ya tengo cuenta) login
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
import '../../features/onboarding/ui/welcome_page.dart';
import '../../features/onboarding/ui/role_selection_page.dart';
import '../services/onboarding_service.dart';
import '../../features/classroom/ui/classroom_page.dart';
import '../../features/classroom/bloc/classroom_bloc.dart';
import '../../features/home/ui/esta_semana_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── AppRouter ─────────────────────────────────────────────
class AppRouter {
  // Rutas como constantes para evitar strings duplicados
  static const String welcome = '/welcome';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String home = '/home';
  static const String classroom = '/classroom';
  static const String estaSemana = '/esta-semana';

  // Rutas del flujo público (sin sesión): onboarding + login.
  // Un usuario no autenticado puede navegar libremente entre estas,
  // sin que el redirect lo empuje de vuelta a welcome en cada paso.
  static const Set<String> _publicFlow = {welcome, roleSelection, login};

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

    // Punto de entrada según el estado del onboarding:
    //   - Primera vez (no completado) → welcome (flujo de bienvenida)
    //   - Ya completado → login directo (el usuario "ya creó su cuenta")
    // OnboardingService se inicializa en main() antes de runApp, por lo
    // que `isCompleted` es síncrono y seguro de leer aquí.
    final initialLocation = OnboardingService.instance.isCompleted ? login : welcome;

    _router = GoRouter(
      initialLocation: initialLocation,

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
          path: welcome,
          builder: (_, __) => const WelcomePage(),
        ),
        GoRoute(
          path: roleSelection,
          builder: (_, __) => const RoleSelectionPage(),
        ),
        GoRoute(
          path: login,
          builder: (_, __) => const LoginPage(),
        ),
        GoRoute(
          path: home,
          builder: (context, state) {
            final authState = context.read<AuthBloc>().state;
            // Parámetro opcional que llega al tocar una notificación
            // de asistencia (se usa para preseleccionar al hijo).
            final studentName = state.uri.queryParameters['studentName'];
            if (authState is AuthAuthenticated) {
              if (authState.user.hasRole('school_admin') ||
                  authState.user.hasRole('director')) {
                return const HomeDirectorPage();
              }
              if (authState.user.hasRole('teacher')) {
                return const HomeDocentePage();
              }
            }
            return HomeV2Page(initialStudentName: studentName);
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
          path: estaSemana,
          builder: (context, state) {
            final studentId = state.uri.queryParameters['studentId'] ?? '';
            final studentName = state.uri.queryParameters['studentName'] ?? 'Alumno';
            return EstaSemanPage(
              studentId: studentId,
              studentName: studentName,
            );
          },
        ),
        GoRoute(
          path: classroom,
          builder: (context, state) {
            final studentId = state.uri.queryParameters['studentId'] ?? '';
            final studentName = state.uri.queryParameters['studentName'] ?? 'Alumno';
            return BlocProvider.value(
              value: context.read<ClassroomBloc>()
                ..add(LoadClassroom(studentId)),
              child: ClassroomPage(studentId: studentId, studentName: studentName),
            );
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
