import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';
import '../../../../core/api/token_store.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';
import '../../../../core/services/google_sign_in_service.dart';
import '../../../../core/services/onboarding_service.dart';

// Los tokens de sesión (access/refresh) viven en TokenStore — única fuente
// de verdad compartida con AuthInterceptor (ver hallazgo I-3 de la
// auditoría: antes este Repository y el interceptor mantenían cada uno su
// propio almacén con las mismas claves, y el refresh nunca funcionaba
// porque el refreshToken solo llegaba al almacén de este Repository, no al
// que leía el interceptor).
//
// El perfil de usuario (current_user_json) SÍ sigue viviendo aquí en
// SharedPreferences — no es un token de sesión, es solo un cache local del
// perfil para arranque instantáneo sin esperar al backend.
class AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  static const String _userKey = 'current_user_json';

  AuthRepository(this._remoteDataSource);

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<UserModel> login({
    required String email,
    required String password,
    String? firebaseToken,
  }) async {
    final loginResponse = await _remoteDataSource.login(
      email: email,
      password: password,
      firebaseToken: firebaseToken,
    );

    await _saveSession(loginResponse.accessToken, loginResponse.refreshToken, loginResponse.user);

    return loginResponse.user;
  }

  // ── loginWithGoogle ───────────────────────────────────────
  // Inicio de sesión/registro con Google Sign-In (Fase 1).
  // Recibe el ID Token de Google, lo envía al backend y guarda la sesión.
  Future<UserModel> loginWithGoogle({
    required String idToken,
    required String invitationToken,
    String? firebaseToken,
  }) async {
    final loginResponse = await _remoteDataSource.loginWithGoogle(
      idToken: idToken,
      invitationToken: invitationToken,
      firebaseToken: firebaseToken,
    );

    await _saveSession(loginResponse.accessToken, loginResponse.refreshToken, loginResponse.user);
    // Login con Google exitoso — este dispositivo ya no necesita volver a
    // mostrar el campo de código en futuros logins (ver LoginPage).
    await OnboardingService.instance.markGoogleParentLinked();

    return loginResponse.user;
  }

  Future<void> logout() async {
    // Leer el refreshToken ANTES de limpiar TokenStore, para que el
    // backend pueda revocar específicamente esta sesión (IM-1).
    final refreshToken = await TokenStore.readRefreshToken();
    try {
      await _remoteDataSource.logout(refreshToken: refreshToken);
    } catch (_) {}
    finally {
      await TokenStore.clear();
      await _clearLocalUser();
      // Cerrar la sesión de Google en el dispositivo para que el próximo
      // login vuelva a mostrar el selector de cuentas.
      try {
        await GoogleSignInService.instance.signOut();
      } catch (_) {}
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await TokenStore.readAccessToken();
    if (token == null) return null;

    final prefs = await _prefs;
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;

    try {
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      await TokenStore.clear();
      await _clearLocalUser();
      return null;
    }
  }

  Future<bool> hasActiveSession() => TokenStore.hasAccessToken();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> _saveSession(String accessToken, String refreshToken, UserModel user) async {
    await TokenStore.save(accessToken: accessToken, refreshToken: refreshToken);
    // Un login nuevo y exitoso reabre la posibilidad de disparar
    // onSessionExpired otra vez si, más adelante, ESTA sesión también
    // termina expirando (el flag es un guard de una sola vez por sesión).
    AuthInterceptor.resetSessionExpiredFlag();

    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearLocalUser() async {
    final prefs = await _prefs;
    await prefs.remove(_userKey);
  }
}
