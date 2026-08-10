// ============================================================
// auth_interceptor.dart — Interceptor de autenticación JWT
// ============================================================
// Un interceptor de Dio se ejecuta ANTES o DESPUÉS de cada
// petición HTTP, sin tener que repetir el código en cada llamada.
//
// Este interceptor hace dos cosas:
//   1. onRequest: agrega el JWT al header de CADA petición automáticamente
//   2. onError: si el servidor devuelve 401 (token expirado),
//      intenta renovar el token con el refresh token y
//      reintenta la petición original automáticamente.
//
// Sin este interceptor, tendrías que agregar el JWT manualmente
// en cada petición y manejar el 401 en cada datasource.
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Callback que el AuthBloc registra para forzar logout cuando el refresh falla.
  static void Function()? onSessionExpired;
  static bool _sessionExpiredFired = false;

  static String? _cachedAccessToken;
  static String? _cachedRefreshToken; // ignore: unused_field

  // ── onRequest ────────────────────────────────────────────
  // Se ejecuta ANTES de enviar cada petición.
  // Aquí leemos el JWT guardado y lo agregamos al header.
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Primero usa la cache en memoria (instantáneo, nunca se cuelga).
    // Si no hay cache, intenta leer de SecureStorage como fallback.
    String? token = _cachedAccessToken;
    if (token == null) {
      try {
        token = await _storage.read(key: _accessTokenKey);
        _cachedAccessToken = token; // llenar cache para próximas requests
      } catch (_) {}
    }
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // ── onError ──────────────────────────────────────────────
  // Se ejecuta cuando el servidor devuelve un error HTTP.
  // Si es un 401 (Unauthorized), intentamos renovar el token.
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final isJwtError = is401 &&
        (err.response?.data?['message'] as String? ?? '')
            .toLowerCase()
            .contains('token');
    if (isJwtError) {
      // El access token JWT expiró. Intentar renovarlo con el refresh token.
      final refreshToken = await _storage.read(key: _refreshTokenKey);

      if (refreshToken != null) {
        try {
          // Crear una instancia nueva de Dio (sin interceptores)
          // para evitar un bucle infinito de 401s
          final refreshDio = Dio();
          final response = await refreshDio.post(
            '${err.requestOptions.baseUrl}auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          // Guardar el nuevo access token
          final newAccessToken = response.data['accessToken'] as String;
          await _storage.write(key: _accessTokenKey, value: newAccessToken);

          // Reintentar la petición original con el nuevo token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await Dio().fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          await _clearTokens();
          if (!_sessionExpiredFired) {
            _sessionExpiredFired = true;
            onSessionExpired?.call();
          }
        }
      }
    }

    handler.next(err);
  }

  static void setCache({required String accessToken, required String refreshToken}) {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    _sessionExpiredFired = false;
  }

  static void clearCache() {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
  }

  // Llamado por AuthRepository después del login.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Guarda en memoria primero (garantizado) y luego en SecureStorage.
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (_) {}
  }

  Future<void> _clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  Future<bool> hasToken() async {
    if (_cachedAccessToken != null) return true;
    try {
      final token = await _storage.read(key: _accessTokenKey);
      return token != null;
    } catch (_) {
      return false;
    }
  }
}
