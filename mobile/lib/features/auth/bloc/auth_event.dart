// ============================================================
// auth_event.dart — Eventos del BLoC de Autenticación
// ============================================================
// En el patrón BLoC (Business Logic Component), los EVENTOS son
// las "acciones" que disparan cambios de estado.
//
// Analogía: el evento es como apretar un botón de una máquina.
//   El botón no hace nada por sí solo — le avisa a la máquina (BLoC)
//   que el usuario quiere hacer algo, y la máquina decide qué hacer.
//
// Flujo:
//   Usuario toca "Iniciar Sesión"
//     → UI dispara LoginEvent(email, password)
//       → AuthBloc recibe el evento
//         → AuthBloc llama al Repository
//           → AuthBloc emite un nuevo AuthState
//             → UI se reconstruye con el nuevo estado
//
// Convenciones:
//   - Todos los eventos extienden la clase base AuthEvent
//   - Los eventos son INMUTABLES (todos sus campos son final)
//   - Usamos 'const' en los constructores para eficiencia de memoria
// ============================================================

// Clase base abstracta de la que heredan todos los eventos.
// 'abstract' significa que no se puede instanciar directamente.
// 'sealed' (Dart 3) garantiza que todos los subtipos están definidos
// en este archivo — permite exhaustividad en el switch del BLoC.
sealed class AuthEvent {
  const AuthEvent();
}

// ── CheckAuthEvent ────────────────────────────────────────
// Se dispara al arrancar la app para verificar si hay una
// sesión activa (token JWT guardado en SecureStorage).
//
// Lo dispara AuthBloc en su constructor (ver auth_bloc.dart):
//   ..add(const CheckAuthEvent())
//
// No lleva datos porque simplemente verifica el estado local.
final class CheckAuthEvent extends AuthEvent {
  const CheckAuthEvent();
}

// ── LoginEvent ────────────────────────────────────────────
// Se dispara cuando el usuario presiona el botón "Iniciar Sesión"
// en la LoginPage.
//
// Lleva email y password (los datos del formulario).
// 'firebaseToken' es opcional — se agrega si Firebase ya se inicializó.
final class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  final String? firebaseToken; // para registrar el dispositivo en FCM

  const LoginEvent({
    required this.email,
    required this.password,
    this.firebaseToken,
  });

  @override
  String toString() => 'LoginEvent(email: $email)'; // No logueamos la contraseña
}

// ── GoogleLoginEvent ──────────────────────────────────────
// Se dispara cuando el usuario presiona "Continuar con Google".
// Lleva el ID Token de Google (obtenido con google_sign_in) y el código
// de invitación entregado por el colegio — obligatorio para el flujo de
// padre, el backend rechaza con INVITATION_REQUIRED si falta.
final class GoogleLoginEvent extends AuthEvent {
  final String idToken;
  final String invitationToken;
  final String? firebaseToken; // para registrar el dispositivo en FCM

  const GoogleLoginEvent({
    required this.idToken,
    required this.invitationToken,
    this.firebaseToken,
  });

  @override
  String toString() => 'GoogleLoginEvent(idToken: ${idToken.length} chars)';
}

// ── LogoutEvent ───────────────────────────────────────────
// Se dispara cuando el usuario presiona "Cerrar Sesión".
// No lleva datos — solo la intención de cerrar sesión.
final class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

// ── ChangePasswordEvent ───────────────────────────────────
// Se dispara desde la pantalla de cambio de contraseña.
final class ChangePasswordEvent extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordEvent({
    required this.currentPassword,
    required this.newPassword,
  });
}
