// ============================================================
// auth_bloc.dart — Business Logic Component de Autenticación
// ============================================================
// El BLoC es el "cerebro" de la feature de autenticación.
// Recibe EVENTOS de la UI y emite ESTADOS de vuelta.
//
// El BLoC NO conoce la UI (no importa ningún widget de Flutter).
// El BLoC NO hace peticiones HTTP directamente (las hace el Repository).
// El BLoC solo orquesta: "Cuando pase X, haz Y y emite estado Z."
//
// Flujo completo del login:
//   LoginPage (UI)
//     → dispatch LoginEvent(email, password)
//       → on<LoginEvent> en AuthBloc
//         → emit(AuthLoading)                 ← UI muestra spinner
//         → repository.login(email, password)
//             ├── Éxito → emit(AuthAuthenticated(user))  ← UI navega a Home
//             └── Error → emit(AuthError(mensaje))       ← UI muestra error
//
// ¿Por qué usar BLoC en lugar de setState o Provider?
//   - Testeable: podemos testear el BLoC sin UI
//   - Predecible: el flujo de datos siempre va en una dirección
//   - Reutilizable: el mismo BLoC sirve para múltiples pantallas
//   - Separación: la UI no sabe nada de HTTP, el BLoC no sabe nada de widgets
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

// Bloc<Event, State> es la clase base del paquete flutter_bloc.
// Le decimos qué tipo de eventos recibe (AuthEvent) y
// qué tipo de estados emite (AuthState).
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  // El BLoC usa el Repository para acceder a los datos.
  // No hace peticiones HTTP directamente.
  final AuthRepository _repository;

  // Constructor: recibimos el Repository por inyección de dependencias.
  // 'super(const AuthInitial())' establece el estado inicial del BLoC.
  AuthBloc(this._repository) : super(const AuthInitial()) {
    // Registramos los manejadores de eventos.
    // Cada 'on<TipoDeEvento>' le dice al BLoC qué hacer cuando
    // recibe ese tipo de evento.
    on<CheckAuthEvent>(_onCheckAuth);
    on<LoginEvent>(_onLogin);
    on<GoogleLoginEvent>(_onGoogleLogin);
    on<LogoutEvent>(_onLogout);
    on<ChangePasswordEvent>(_onChangePassword);
    on<UserUpdatedEvent>(_onUserUpdated);
  }

  // ── _onUserUpdated ────────────────────────────────────────
  // Re-cachea y re-emite el usuario sin pegarle al backend (ver
  // AuthEvent.UserUpdatedEvent). No pasa por AuthLoading — es una
  // actualización silenciosa, no un login nuevo.
  Future<void> _onUserUpdated(
    UserUpdatedEvent event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.updateCachedUser(event.user);
    emit(AuthAuthenticated(event.user));
  }

  // ── _onCheckAuth ─────────────────────────────────────────
  // Se ejecuta cuando el BLoC recibe un CheckAuthEvent.
  // Verifica si hay una sesión guardada localmente.
  // Se llama al arrancar la app (desde main.dart).
  //
  // 'emit' es la función que envía un nuevo estado a la UI.
  // Cada vez que llamamos emit(), los BlocBuilder en la UI se reconstruyen.
  Future<void> _onCheckAuth(
    CheckAuthEvent event,
    Emitter<AuthState> emit,
  ) async {
    // Mostrar spinner mientras verificamos
    emit(const AuthLoading());

    try {
      // Intentar obtener el usuario guardado localmente
      // (sin hacer petición HTTP — solo lee del SecureStorage)
      final user = await _repository.getCurrentUser();
      debugPrint('[AUTH-CHECK] getCurrentUser() → ${user == null ? "null (sin sesión)" : "usuario ${user.email}"}');

      if (user != null) {
        // Hay una sesión activa → navegar a Home
        emit(AuthAuthenticated(user));
      } else {
        // No hay sesión → mostrar pantalla de login
        emit(const AuthUnauthenticated());
      }
    } catch (e, st) {
      // Si algo falla al leer el storage, pedir login
      debugPrint('[AUTH-CHECK] EXCEPCIÓN al restaurar sesión: $e\n$st');
      emit(const AuthUnauthenticated());
    }
  }

  // ── _onLogin ──────────────────────────────────────────────
  // Se ejecuta cuando el usuario presiona "Iniciar Sesión".
  // Llama al backend, guarda los tokens y navega a Home.
  Future<void> _onLogin(
    LoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    // 1. Mostrar indicador de carga
    emit(const AuthLoading());
    final _t0 = DateTime.now().millisecondsSinceEpoch;

    try {
      // 2. Llamar al Repository (que llama al DataSource → Backend)
      final user = await _repository.login(
        email: event.email,
        password: event.password,
        firebaseToken: event.firebaseToken,
      );

      // 3. Login exitoso → emitir estado autenticado con los datos del usuario
      emit(AuthAuthenticated(user));
      print('[FLOW] login-to-authenticated = '
          '${DateTime.now().millisecondsSinceEpoch - _t0} ms');
    } catch (e) {
      // 4. Login fallido → emitir error con mensaje legible
      // e.toString() incluye el mensaje que pusimos en _handleError() del ApiClient
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ── _onGoogleLogin ────────────────────────────────────────
  // Se ejecuta cuando el usuario presiona "Continuar con Google".
  // Envía el ID Token al backend, guarda la sesión y navega a Home.
  Future<void> _onGoogleLogin(
    GoogleLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final user = await _repository.loginWithGoogle(
        idToken: event.idToken,
        invitationToken: event.invitationToken,
        firebaseToken: event.firebaseToken,
      );

      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ── _onLogout ─────────────────────────────────────────────
  // Se ejecuta cuando el usuario presiona "Cerrar Sesión".
  // Limpia los tokens locales y notifica al backend.
  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    // Podríamos mostrar un loading, pero el logout es casi instantáneo
    // porque incluso si falla el backend, limpiamos los datos locales
    emit(const AuthLoading());

    try {
      await _repository.logout();
    } catch (_) {
      // El Repository ya maneja errores en logout (ver auth_repository.dart)
      // Siempre llegamos aquí con los datos locales ya limpios
    }

    // Siempre terminamos en Unauthenticated, haya error o no
    emit(const AuthUnauthenticated());
  }

  // ── _onChangePassword ────────────────────────────────────
  // Se ejecuta cuando el usuario confirma el cambio de contraseña.
  Future<void> _onChangePassword(
    ChangePasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _repository.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      // Emitir estado de éxito para que la UI muestre confirmación
      emit(const AuthPasswordChanged());
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
