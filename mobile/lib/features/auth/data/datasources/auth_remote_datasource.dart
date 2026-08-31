// ============================================================
// auth_remote_datasource.dart — Fuente de datos remota de Auth
// ============================================================
// En Clean Architecture, un DataSource es quien REALMENTE hace
// la llamada HTTP al backend. El Repository usa el DataSource.
//
// Flujo de datos:
//   UI → BLoC → Repository → DataSource → API Backend
//                                           ↓
//   UI ← BLoC ← Repository ← DataSource ← Respuesta JSON
//
// ¿Por qué esta capa existe?
// Porque el Repository solo sabe "necesito datos de auth".
// El DataSource sabe el CÓMO: qué URL, qué método HTTP, qué JSON.
// Esto nos permite cambiar el backend sin tocar el BLoC ni la UI.
//
// Endpoints que usa este DataSource:
//   POST /auth/login          → iniciar sesión
//   POST /auth/logout         → cerrar sesión
//   POST /auth/change-password → cambiar contraseña
// ============================================================

import '../../../../core/api/api_client.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  // Necesitamos el ApiClient para hacer las peticiones HTTP
  final ApiClient _client;

  // Constructor: recibimos el ApiClient por inyección de dependencias
  // (se lo damos desde afuera en lugar de crearlo aquí)
  AuthRemoteDataSource(this._client);

  // ── login ─────────────────────────────────────────────────
  // Envía las credenciales al backend y recibe los tokens JWT.
  //
  // Parámetros:
  //   email    → correo del usuario
  //   password → contraseña en texto plano (el backend la compara con bcrypt)
  //   firebaseToken → token FCM para push notifications (opcional)
  //
  // Devuelve: LoginResponse con user + accessToken + refreshToken
  // Lanza:    Exception si las credenciales son incorrectas (401)
  //           o si hay error de red
  Future<LoginResponse> login({
    required String email,
    required String password,
    String? firebaseToken,
  }) async {
    // Construimos el cuerpo de la petición como un Map
    // (se serializa a JSON automáticamente con Dio)
    final body = {
      'email': email,
      'password': password,
      // Incluimos el firebaseToken solo si no es null
      // El if dentro de un Map en Dart: if (condicion) 'clave': 'valor'
      if (firebaseToken != null) 'firebaseToken': firebaseToken,
    };

    // POST /auth/login → devuelve {user, accessToken, refreshToken}
    // _client.post() ya maneja los errores de red con mensajes claros
    final response = await _client.post('auth/login', data: body);

    // Convertimos el JSON de la respuesta en nuestro modelo tipado
    // response.data es el cuerpo de la respuesta ya decodificado
    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── syncPushToken ─────────────────────────────────────────
  // El token FCM antes solo se guardaba al loguearse — si cambia con la
  // sesión ya activa (reinstalar la app, rotación normal de Firebase), no
  // había forma de resincronizarlo hasta el siguiente login, y el push
  // quedaba muerto en silencio. Se llama al arrancar con sesión ya
  // restaurada y cuando Firebase avisa que el token rotó.
  Future<void> syncPushToken(String firebaseToken) async {
    await _client.post('auth/push-token', data: {'firebaseToken': firebaseToken});
  }

  // ── loginWithGoogle ───────────────────────────────────────
  // Inicio de sesión/registro con Google Sign-In (Fase 1).
  //
  // Envía ÚNICAMENTE el ID Token de Google al backend. El backend lo
  // valida criptográficamente (firma, issuer, audience, expiración) y
  // crea/asigna el rol parent si es una cuenta nueva.
  //
  // Parámetros:
  //   idToken       → ID Token de Google (JWT firmado por Google)
  //   firebaseToken → token FCM para push notifications (opcional)
  //
  // Devuelve: LoginResponse con user + accessToken + refreshToken
  //           (misma estructura que login)
  Future<LoginResponse> loginWithGoogle({
    required String idToken,
    required String invitationToken,
    String? firebaseToken,
  }) async {
    final body = {
      'idToken': idToken,
      'invitationToken': invitationToken,
      if (firebaseToken != null) 'firebaseToken': firebaseToken,
    };

    // POST /auth/google → devuelve {user, accessToken, refreshToken}
    final response = await _client.post('auth/google', data: body);

    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── logout ────────────────────────────────────────────────
  // Notifica al backend que el usuario cerró sesión.
  // El backend elimina el Firebase token para dejar de enviar
  // notificaciones a este dispositivo, y revoca el refreshToken de ESTA
  // sesión (hallazgo IM-1 — antes el backend no invalidaba nada, así que
  // un refresh token seguía siendo válido hasta 7 días después de
  // "cerrar sesión"). Enviarlo aquí revoca solo este dispositivo, no
  // otras sesiones del mismo usuario.
  //
  // Nota: los tokens JWT del lado del cliente siempre se eliminan
  // en el Repository, independientemente de la respuesta del backend.
  Future<void> logout({String? refreshToken}) async {
    // POST /auth/logout (este endpoint requiere JWT — no es @Public)
    // El AuthInterceptor agrega el Bearer token automáticamente
    await _client.post(
      'auth/logout',
      data: refreshToken != null ? {'refreshToken': refreshToken} : null,
    );
  }

  // ── changePassword ────────────────────────────────────────
  // Cambia la contraseña del usuario autenticado.
  //
  // Parámetros:
  //   currentPassword → contraseña actual (para verificar identidad)
  //   newPassword     → nueva contraseña (mínimo 8 chars, mayús, minús, número)
  //
  // Lanza: Exception si la contraseña actual es incorrecta (400)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      'auth/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    // Si llega aquí sin excepción, el cambio fue exitoso
  }
}
