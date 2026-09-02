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
import 'package:flutter_svg/flutter_svg.dart';
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
// ── _SplashPage ───────────────────────────────────────────
// Mismo fondo (#5B4A9E) y mismo isotipo (K + wordmark KOLEXA, blanco)
// que el splash NATIVO de Android (ver launch_background.xml /
// splash_icon.xml) — pathData copiado 1:1 del vector nativo.
//
// El splash nativo se retira solo, automáticamente, en el primer frame
// que dibuja Flutter (comportamiento de la SplashScreen API de Android,
// no algo que controlemos) — ese primer frame antes era literalmente
// LoginPage, porque `initialLocation` apuntaba ahí y el redirect no se
// resuelve hasta que AuthBloc termina de leer la sesión guardada (unos
// cuantos ms). Resultado: un flash real de la pantalla de login antes
// de aterrizar en home, aunque hubiera sesión. Esta pantalla reemplaza
// ese primer frame por algo visualmente idéntico al splash nativo, así
// la transición nativo→Flutter es imperceptible mientras se resuelve.
const _kSplashBg = Color(0xFF5B4A9E);
const _kSvgKolexaSplash =
    '<svg width="63" height="98" viewBox="0 0 63 98" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<g transform="translate(7.5,0)">'
    '<path fill="#FFFFFF" d="M7.78418,0C11.0081,0.000251297 13.6211,2.6139 13.6211,5.83789V26.5635L17.0762,29.6748L36.8174,11.9004C39.4129,9.56337 43.4118,9.77292 45.749,12.3682C48.0861,14.9638 47.8768,18.9626 45.2812,21.2998L26.5273,38.1855L36.8174,47.4512C39.4131,49.7883 39.6233,53.7871 37.2861,56.3828C34.949,58.9784 30.9502,59.1876 28.3545,56.8506L15.9766,45.7051C15.179,45.7342 14.3788,45.6147 13.6211,45.3457V66.1621C13.6211,69.3861 11.0081,71.9997 7.78418,72H5.83789C2.61374,72 0,69.3863 0,66.1621V5.83789C0,2.61374 2.61374,0 5.83789,0H7.78418Z"/>'
    '</g>'
    '<g transform="translate(0,86)">'
    '<path fill="#FFFFFF" d="M0,11.0583V0.149258H1.97621V5.16169H2.10937L6.36541,0.149258H8.77841L4.55966,5.0445L8.81569,11.0583H6.43998L3.18537,6.3815L1.97621,7.80906V11.0583H0ZM20.0633,5.6038C20.0633,6.77923 19.8431,7.78598 19.4028,8.62405C18.966,9.45856 18.3694,10.0978 17.613,10.5417C16.8602,10.9856 16.0061,11.2075 15.0509,11.2075C14.0956,11.2075 13.2398,10.9856 12.4834,10.5417C11.7306,10.0942 11.134,9.45324 10.6936,8.61872C10.2568,7.78065 10.0384,6.77568 10.0384,5.6038C10.0384,4.42838 10.2568,3.42341 10.6936,2.58889C11.134,1.75082 11.7306,1.10984 12.4834,0.665948C13.2398,0.222057 14.0956,0.000110567 15.0509,0.000110567C16.0061,0.000110567 16.8602,0.222057 17.613,0.665948C18.3694,1.10984 18.966,1.75082 19.4028,2.58889C19.8431,3.42341 20.0633,4.42838 20.0633,5.6038ZM18.0764,5.6038C18.0764,4.77639 17.9468,4.07859 17.6876,3.51041C17.4319,2.93868 17.0768,2.50721 16.6222,2.21602C16.1677,1.92128 15.6439,1.7739 15.0509,1.7739C14.4578,1.7739 13.934,1.92128 13.4795,2.21602C13.0249,2.50721 12.6681,2.93868 12.4088,3.51041C12.1531,4.07859 12.0253,4.77639 12.0253,5.6038C12.0253,6.43122 12.1531,7.13079 12.4088,7.70253C12.6681,8.27071 13.0249,8.70217 13.4795,8.99691C13.934,9.28811 14.4578,9.4337 15.0509,9.4337C15.6439,9.4337 16.1677,9.28811 16.6222,8.99691C17.0768,8.70217 17.4319,8.27071 17.6876,7.70253C17.9468,7.13079 18.0764,6.43122 18.0764,5.6038ZM22.6816,11.0583V0.149258H24.6578V9.40174H29.4625V11.0583H22.6816ZM31.9277,11.0583V0.149258H39.0229V1.80586H33.9039V4.76751H38.6554V6.42412H33.9039V9.40174H39.0655V11.0583H31.9277ZM43.4403,0.149258L45.8427,4.14429H45.9279L48.3409,0.149258H50.5941L47.233,5.6038L50.6474,11.0583H48.3569L45.9279,7.08995H45.8427L43.4137,11.0583H41.1339L44.5803,5.6038L41.1765,0.149258H43.4403ZM54.2964,11.0583H52.1871L56.0276,0.149258H58.4672L62.3131,11.0583H60.2037L57.29,2.38647H57.2048L54.2964,11.0583ZM54.3657,6.78101H60.1185V8.36836H54.3657V6.78101Z"/>'
    '</g>'
    '</svg>';

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSplashBg,
      body: Center(
        child: SizedBox(
          width: 84,
          height: 131,
          child: SvgPicture.string(_kSvgKolexaSplash),
        ),
      ),
    );
  }
}

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
  static const String splash = '/splash';
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
      initialLocation: splash,

      // refreshListenable: go_router re-evalúa el redirect cada vez
      // que el BLoC emite un nuevo estado.
      // Sin esto, el redirect solo se ejecuta una vez al arrancar.
      refreshListenable: refreshStream,

      // redirect: se llama ANTES de mostrar cada ruta.
      // Decide si redirigir según el estado de Auth.
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        final location = state.matchedLocation;

        // Mientras AuthBloc resuelve la sesión: quedarse en el splash
        // propio (ver _SplashPage) — nunca dejar que se vea login/home de
        // fondo antes de saber a cuál corresponde ir.
        if (authState is AuthInitial || authState is AuthLoading) {
          return location == splash ? null : splash;
        }

        // Sesión resuelta: navegar al destino.
        if (authState is AuthAuthenticated) {
          if (location == splash || _publicFlow.contains(location)) return home;
          return null;
        }

        if (authState is AuthUnauthenticated || authState is AuthError) {
          if (location == splash || !_publicFlow.contains(location)) return login;
          return null;
        }

        return null;
      },

      routes: [
        GoRoute(
          path: splash,
          // Sin fade acá: es la primerísima página que se muestra, justo
          // encima del splash nativo — cualquier transición (aunque sea
          // un fade-in) expondría el fondo por defecto del tema durante
          // esa animación en vez de una continuación perfecta del morado
          // nativo. NoTransitionPage la pinta de una, sin animar nada.
          pageBuilder: (_, state) =>
              NoTransitionPage<void>(key: state.pageKey, child: const _SplashPage()),
        ),
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
