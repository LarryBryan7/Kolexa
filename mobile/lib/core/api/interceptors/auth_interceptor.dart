// ============================================================
// auth_interceptor.dart — Interceptor de autenticación JWT
// ============================================================
// Un interceptor de Dio se ejecuta ANTES o DESPUÉS de cada
// petición HTTP, sin tener que repetir el código en cada llamada.
//
// Este interceptor hace dos cosas:
//   1. onRequest: agrega el JWT al header de CADA petición automáticamente
//   2. onError: si el servidor devuelve 401 con code SESSION_TOKEN_EXPIRED
//      (sesión KOLEXA vencida), intenta renovar el token con el refresh
//      token y reintenta la petición original automáticamente.
//
// La lectura/escritura de los tokens vive en TokenStore (única fuente de
// verdad — ver token_store.dart), no aquí. Antes de ese fix (hallazgo I-3)
// este archivo tenía su propio almacén (FlutterSecureStorage) separado del
// de AuthRepository (SharedPreferences), y el refresh nunca funcionaba
// porque el refreshToken jamás llegaba al almacén que este interceptor leía.
//
// Clasificación por `code`, no por substring de `message` (hallazgo H-01):
// antes se usaba message.contains('token'), lo que confundía el
// GOOGLE_TOKEN_EXPIRED de la sincronización de Classroom (token de Google,
// nada que ver con la sesión KOLEXA) con una sesión KOLEXA vencida —
// disparaba un refresh innecesario y, si el reintento volvía a fallar
// (como es de esperar, porque el problema es el token de Google, no el de
// KOLEXA), terminaba forzando un logout completo del padre/docente solo
// porque Classroom pedía reconectarse.
// ============================================================

import 'package:dio/dio.dart';
import '../token_store.dart';

class AuthInterceptor extends Interceptor {
  // Fábrica del Dio "pelado" (sin interceptores, para no re-entrar en un
  // bucle de 401s) usado para refrescar y reintentar. Inyectable solo para
  // tests — en la app real siempre es el Dio() por defecto. Sin esto no
  // hay forma de probar el flujo de refresh+retry sin red real.
  AuthInterceptor({Dio Function()? bareDioFactory})
      : _bareDioFactory = bareDioFactory ?? (() => Dio());

  final Dio Function() _bareDioFactory;

  // Callback que el AuthBloc registra para forzar logout cuando el refresh falla.
  static void Function()? onSessionExpired;
  static bool _sessionExpiredFired = false;

  // ── onRequest ────────────────────────────────────────────
  // Se ejecuta ANTES de enviar cada petición.
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStore.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // ── onError ──────────────────────────────────────────────
  // Se ejecuta cuando el servidor devuelve un error HTTP.
  // Solo se intenta refresh cuando el backend marca explícitamente el 401
  // como SESSION_TOKEN_EXPIRED (ver JwtAuthGuard.handleRequest en el
  // backend) — nunca por inspeccionar el texto de `message`.
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final code = _extractCode(err);
    final isSessionExpired = is401 && code == 'SESSION_TOKEN_EXPIRED';

    if (isSessionExpired) {
      final baseUrl = err.requestOptions.baseUrl;
      final newAccessToken = await TokenStore.refreshAccessToken(
        (refreshToken) => _callRefreshEndpoint(refreshToken, baseUrl),
      );

      if (newAccessToken != null) {
        try {
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _bareDioFactory().fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (retryError) {
          // El REINTENTO en sí falló (podría ser un error del propio
          // endpoint original, no del token nuevo) — no es motivo de
          // logout: el access token ya es válido para el resto de la app.
          // Se propaga el error del reintento tal cual.
          return handler.next(
            retryError is DioException ? retryError : err,
          );
        }
      }

      // El refresh falló de verdad (sin refreshToken guardado, o el
      // backend lo rechazó) — ahí sí la sesión está perdida.
      await TokenStore.clear();
      if (!_sessionExpiredFired) {
        _sessionExpiredFired = true;
        onSessionExpired?.call();
      }
    }

    handler.next(err);
  }

  static String? _extractCode(DioException err) {
    final data = err.response?.data;
    if (data is Map) return data['code'] as String?;
    return null;
  }

  Future<String?> _callRefreshEndpoint(String refreshToken, String baseUrl) async {
    try {
      // Dio "pelado", sin interceptores — evita un bucle infinito de 401s.
      final refreshDio = _bareDioFactory();
      final response = await refreshDio.post(
        '${baseUrl}auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final token = response.data is Map ? response.data['accessToken'] : null;
      return token is String ? token : null;
    } catch (_) {
      return null;
    }
  }

  static void resetSessionExpiredFlag() {
    _sessionExpiredFired = false;
  }
}
