// ============================================================
// token_store.dart — Única fuente de verdad de los tokens de sesión
// ============================================================
// ANTES (hallazgo I-3 de la auditoría): AuthInterceptor guardaba/leía los
// tokens con FlutterSecureStorage, mientras que AuthRepository los
// guardaba/leía con SharedPreferences — dos almacenes distintos para las
// mismas claves ('access_token', 'refresh_token'). AuthRepository nunca
// llamaba a AuthInterceptor.saveTokens() (ese método quedaba sin uso), solo
// a AuthInterceptor.setCache() (cache en memoria). Consecuencia real: el
// refreshToken JAMÁS llegaba a FlutterSecureStorage, así que cuando el
// access token expiraba (~1h) el interceptor leía un refreshToken nulo,
// el refresh fallaba siempre, y se forzaba logout — con el agravante de
// que el login de Google ahora exige invitationToken, así que el padre
// tenía que volver a pedir el código al colegio solo por haber usado la
// app más de una hora.
//
// AHORA: una sola clase, un solo almacén persistente (SharedPreferences —
// se mantiene deliberadamente, ver nota de rendimiento abajo) y una cache
// en memoria para lecturas síncronas-rápidas en el interceptor. Tanto
// AuthRepository como AuthInterceptor pasan por aquí; ninguno mantiene su
// propia copia.
//
// Nota de rendimiento (por qué SharedPreferences y no FlutterSecureStorage
// como almacén persistente): flutter_secure_storage inicializa el Keystore
// de Android en su primera lectura, lo que tarda 20-30s en dispositivos con
// chipset Exynos (gama baja/media del piloto — Samsung A-series). Los
// tokens de este store son JWT de corta vida (~1h el access, días el
// refresh) protegidos por el sandbox de la app, no secretos de largo plazo
// — el mismo trade-off que ya usaba AuthRepository antes de este fix, solo
// que ahora aplicado de forma consistente en un solo lugar.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  TokenStore._();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static String? _accessToken;
  static String? _refreshToken;

  // Deduplica refresh concurrente: si dos requests reciben 401 casi al
  // mismo tiempo, ambas deben esperar el MISMO refresh en curso en vez de
  // disparar dos llamadas a /auth/refresh en paralelo (que podrían pisarse
  // el resultado o gastar el pool de conexiones del backend sin necesidad).
  static Future<String?>? _refreshInFlight;

  /// Token de acceso cacheado en memoria (null si el proceso no lo cargó
  /// todavía — usar [readAccessToken] si se necesita garantía de lectura).
  static String? get cachedAccessToken => _accessToken;

  /// Guarda el par de tokens de una sesión nueva (login / loginWithGoogle).
  static Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_accessTokenKey, accessToken),
      prefs.setString(_refreshTokenKey, refreshToken),
    ]);
  }

  /// Actualiza solo el access token (resultado de un refresh exitoso) —
  /// el refresh token no cambia (el backend no lo rota, ver auth.service.ts).
  static Future<void> updateAccessToken(String accessToken) async {
    _accessToken = accessToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
  }

  /// Limpia la sesión por completo (logout, o refresh fallido = sesión
  /// realmente perdida).
  static Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _refreshInFlight = null;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
    ]);
  }

  // Precarga la cache en memoria desde SharedPreferences. Se llama sola la
  // primera vez que se necesita un token y la cache está vacía (arranque
  // en frío del proceso, antes de que login()/CheckAuthEvent hayan corrido).
  static Future<void> _hydrate() async {
    if (_accessToken != null || _refreshToken != null) return;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
  }

  static Future<String?> readAccessToken() async {
    if (_accessToken != null) return _accessToken;
    await _hydrate();
    return _accessToken;
  }

  static Future<String?> readRefreshToken() async {
    if (_refreshToken != null) return _refreshToken;
    await _hydrate();
    return _refreshToken;
  }

  static Future<bool> hasAccessToken() async => (await readAccessToken()) != null;

  /// Ejecuta [doRefresh] a lo sumo UNA vez aunque se llame concurrentemente
  /// desde varios requests con 401 simultáneo — todas las llamadas
  /// concurrentes esperan el mismo resultado. [doRefresh] recibe el
  /// refreshToken vigente y debe devolver el nuevo accessToken, o null si
  /// el refresh falló (refreshToken ausente/inválido/revocado). En caso de
  /// éxito, el nuevo accessToken queda guardado (memoria + persistente)
  /// antes de devolverlo.
  static Future<String?> refreshAccessToken(
    Future<String?> Function(String refreshToken) doRefresh,
  ) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final future = _performRefresh(doRefresh);
    _refreshInFlight = future;
    return future;
  }

  static Future<String?> _performRefresh(
    Future<String?> Function(String) doRefresh,
  ) async {
    try {
      final refreshToken = await readRefreshToken();
      if (refreshToken == null) return null;

      final newAccessToken = await doRefresh(refreshToken);
      if (newAccessToken != null) {
        await updateAccessToken(newAccessToken);
      }
      return newAccessToken;
    } finally {
      _refreshInFlight = null;
    }
  }
}
