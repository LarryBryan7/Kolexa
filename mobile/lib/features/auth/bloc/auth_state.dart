// ============================================================
// auth_state.dart — Estados del BLoC de Autenticación
// ============================================================
// Los ESTADOS representan las diferentes "fotografías" posibles
// de la pantalla de autenticación en un momento dado.
//
// La UI escucha los estados con BlocBuilder y se reconstruye
// cada vez que el BLoC emite uno nuevo.
//
// Diagrama de estados posibles:
//
//   App arranca
//       │
//       ▼
//   AuthInitial ──── CheckAuthEvent ────► AuthLoading
//                                             │
//                                     ┌───────┴───────┐
//                                     │               │
//                                     ▼               ▼
//                             AuthAuthenticated  AuthUnauthenticated
//                                     │               │
//                             LoginEvent              │
//                             LogoutEvent             │
//                                     │               │
//                                     └───────────────┘
//
// Convenciones:
//   - Todos los estados extienden AuthState
//   - Los estados son INMUTABLES (todos sus campos son final)
//   - 'sealed' garantiza exhaustividad en el switch de la UI
// ============================================================

import '../data/models/user_model.dart';

// Clase base de todos los estados de autenticación
sealed class AuthState {
  const AuthState();
}

// ── AuthInitial ───────────────────────────────────────────
// Estado inicial cuando el BLoC acaba de crearse.
// La app nunca debería mostrar UI en este estado —
// CheckAuthEvent se dispara inmediatamente al crear el BLoC.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

// ── AuthLoading ───────────────────────────────────────────
// La app está verificando la sesión o procesando un login/logout.
// La UI muestra un indicador de carga (CircularProgressIndicator)
// mientras esté en este estado.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

// ── AuthAuthenticated ─────────────────────────────────────
// El usuario tiene una sesión activa válida.
// Lleva el UserModel para que la UI pueda mostrar el nombre,
// avatar y otros datos del usuario sin hacer otra petición.
//
// Ejemplo de uso en la UI:
//   if (state is AuthAuthenticated) {
//     Text('Bienvenido, ${state.user.fullName}');
//   }
final class AuthAuthenticated extends AuthState {
  final UserModel user; // El usuario autenticado con sus datos

  // true solo en el instante justo después del PRIMER login con Google
  // exitoso de este dispositivo (ver AuthBloc._onGoogleLogin) — LoginPage
  // lo usa para navegar a HijosEncontradosPage en vez de directo a Home.
  // false en cualquier otro caso (CheckAuthEvent, login por contraseña,
  // logins de Google posteriores).
  final bool isFirstGoogleLogin;

  const AuthAuthenticated(this.user, {this.isFirstGoogleLogin = false});

  @override
  String toString() => 'AuthAuthenticated(user: ${user.email})';
}

// ── AuthUnauthenticated ───────────────────────────────────
// No hay sesión activa. La app debe mostrar la pantalla de login.
// También se emite después de un logout exitoso.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

// ── AuthError ─────────────────────────────────────────────
// Ocurrió un error durante login, logout o verificación de sesión.
// Lleva el mensaje de error para mostrarlo al usuario.
//
// Nota: después de mostrar el error, el BLoC vuelve a emitir
// AuthUnauthenticated para que la UI quede en estado limpio.
final class AuthError extends AuthState {
  final String message; // Mensaje de error legible para el usuario

  const AuthError(this.message);

  @override
  String toString() => 'AuthError(message: $message)';
}

// ── AuthPasswordChanged ───────────────────────────────────
// El cambio de contraseña fue exitoso.
// La UI puede mostrar un SnackBar de éxito y navegar atrás.
final class AuthPasswordChanged extends AuthState {
  const AuthPasswordChanged();
}
