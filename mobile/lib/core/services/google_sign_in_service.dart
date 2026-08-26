// ============================================================
// google_sign_in_service.dart — Servicio de Google Sign-In (Fase 1)
// ============================================================
// Encapsula la obtención del ID Token de Google para el login
// de padres con cuenta Google.
//
// FLUJO (Fase 1):
//   1. El usuario toca "Continuar con Google" en la LoginPage.
//   2. Este servicio abre el selector de cuentas de Google.
//   3. google_sign_in devuelve el ID Token (JWT firmado por Google).
//   4. La UI envía ese ID Token al backend (POST /auth/google).
//   5. El backend lo valida criptográficamente y crea/asigna el rol parent.
//
// SEGURIDAD:
//   - El ID Token es la ÚNICA fuente de verdad. El backend lo valida
//     (firma, issuer, audience, expiración) y NUNCA confía en campos
//     enviados por el cliente.
//   - Este servicio NO envía datos al backend; solo obtiene el token.
// ============================================================

import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  // Instancia única (singleton) para reutilizar la sesión de Google.
  static final GoogleSignInService instance = GoogleSignInService._();

  GoogleSignInService._();

  // ── Configuración del Client ID ───────────────────────────
  // IMPORTANTE: este es el SERVER (web) Client ID de Google Cloud,
  // el MISMO que usa el backend como GOOGLE_CLIENT_ID.
  //
  // En Google Cloud Console → Credenciales → OAuth 2.0 Client IDs,
  // el "Web client" (o "Server") ID es el que debe ir aquí.
  //
  // NOTA: para el piloto, reemplaza este valor por el Client ID real
  // de tu proyecto de Google Cloud. No lo subas a git si es sensible.
  static const String _serverClientId =
      '171691080214-1t7108i5q0997upk7l6n7tq2ssr3a7r3.apps.googleusercontent.com';

  // Client ID de tipo iOS (Google Cloud Console → Credenciales → "Kolexa
  // iOS"). Solo lo usa el plugin en iOS/Web — en Android se ignora, ahí
  // el client ID sale de google-services.json.
  static const String _iosClientId =
      '171691080214-cj1osmcu6t4csu49onfbuetq40p3j6m6.apps.googleusercontent.com';

  // Instancia de GoogleSignIn configurada con el server client ID.
  // 'webClientId' es el ID del cliente web/servidor; es el que permite
  // obtener un ID Token válido para que el backend lo verifique.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _iosClientId,
    serverClientId: _serverClientId,
  );

  // ── signIn ────────────────────────────────────────────────
  // Abre el selector de cuentas de Google y devuelve el ID Token.
  //
  // signOut() previo a propósito: sin esto, si un intento anterior falló en
  // NUESTRO backend (ej. INVITATION_EMAIL_MISMATCH — cuenta de Google
  // correcta, pero no es la que espera la invitación), el plugin
  // google_sign_in sigue considerando esa cuenta "activa" y la reutiliza en
  // silencio en el siguiente toque, sin volver a mostrar el selector — el
  // usuario queda sin forma de elegir otra cuenta desde la UI. Quien llama
  // a signIn() SIEMPRE está en LoginPage sin sesión propia todavía (si ya
  // estuviera autenticado en Kolexa, el router lo habría mandado a home),
  // así que forzar el selector de cuentas en cada intento es seguro.
  //
  // Devuelve: el ID Token (String) listo para enviar al backend.
  // Lanza:    Exception si el usuario cancela o hay un error.
  Future<String> signIn() async {
    await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();
    if (account == null) {
      // El usuario canceló el selector de cuentas.
      throw Exception('Inicio de sesión con Google cancelado');
    }

    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('No se pudo obtener el ID Token de Google');
    }

    return idToken;
  }

  // ── signOut ───────────────────────────────────────────────
  // Cierra la sesión de Google en el dispositivo.
  // Se llama al hacer logout para que el próximo login vuelva a
  // mostrar el selector de cuentas.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
