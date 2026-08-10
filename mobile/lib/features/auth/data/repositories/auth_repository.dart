import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';

// Usa SharedPreferences (sin Keystore de Android) para arranque instantáneo.
// flutter_secure_storage inicializa el Keystore en la primera lectura, lo que
// tarda 20-30 s en dispositivos con chipset Exynos (Samsung A-series, etc.).
// Los tokens JWT expiran en 1h y el sandbox de Android protege el almacenamiento.
class AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  static const String _accessTokenKey  = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey         = 'current_user_json';

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

    AuthInterceptor.setCache(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );
    await _saveSession(loginResponse.accessToken, loginResponse.refreshToken, loginResponse.user);

    return loginResponse.user;
  }

  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {}
    finally {
      AuthInterceptor.clearCache();
      await _clearLocalData();
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await _prefs;
    final token = prefs.getString(_accessTokenKey);
    if (token == null) return null;

    // Pre-cargar tokens en memoria para que el interceptor los tenga listos
    final refreshToken = prefs.getString(_refreshTokenKey);
    AuthInterceptor.setCache(accessToken: token, refreshToken: refreshToken ?? '');

    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;

    try {
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      await _clearLocalData();
      return null;
    }
  }

  Future<bool> hasActiveSession() async {
    final prefs = await _prefs;
    return prefs.containsKey(_accessTokenKey);
  }

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
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString(_accessTokenKey, accessToken),
      prefs.setString(_refreshTokenKey, refreshToken),
      prefs.setString(_userKey, jsonEncode(user.toJson())),
    ]);
  }

  Future<void> _clearLocalData() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_userKey),
    ]);
  }
}
