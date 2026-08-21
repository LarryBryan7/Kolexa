// ============================================================
// onboarding_service.dart — Snapshot del último login con Google
// ============================================================
// Todos los roles (padre, docente, director) inician sesión con
// Google + código de invitación — no hay onboarding de bienvenida
// ni selección de rol, el backend valida el rol por el email
// (ver AuthService.loginWithGoogle).
//
// Este servicio guarda un estado liviano, puramente de UI, para que
// LoginPage sepa si este dispositivo ya vinculó Google exitosamente
// antes (y por lo tanto ya no debe pedir el código de nuevo, ver
// AuthService.loginWithGoogle) y pueda mostrar un saludo con el
// nombre/avatar de la última cuenta vinculada.
//
// Implementación:
//   - Usa shared_preferences (clave-valor rápido, arranque instantáneo).
//   - Es un singleton (patrón igual que PushNotificationsService)
//     para que LoginPage pueda leer el estado de forma SÍNCRONA
//     sin esperar un Future en cada build.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  // true una vez que este dispositivo completó con éxito el login con
  // Google + código de invitación al menos una vez (cualquier rol). A
  // partir de ahí, LoginPage deja de mostrar el campo de código — el
  // backend ya no lo exige para una cuenta vinculada (ver
  // AuthService.loginWithGoogle), así que mostrarlo de nuevo no tiene
  // sentido, ni siquiera después de cerrar sesión. Nunca se limpia en
  // logout a propósito.
  static const String _keyGoogleLinked = 'google_parent_linked_once_v1';

  // Snapshot liviano de la última cuenta vinculada con Google — SOBREVIVE
  // al logout a propósito (a diferencia de current_user_json en
  // AuthRepository, que sí se borra). Se usa solo para el saludo
  // personalizado ("Hola Larry 👋" + su avatar) en la pantalla de login
  // cuando ya no hace falta el código — no es una fuente de verdad de
  // sesión, solo texto de UI.
  static const String _keyLastFirstName = 'last_parent_first_name_v1';
  static const String _keyLastLastName = 'last_parent_last_name_v1';
  static const String _keyLastAvatar = 'last_parent_avatar_v1';

  // Instancia cacheada de SharedPreferences. Se inicializa en main()
  // ANTES de runApp para que el resto de la app la lea sin await.
  SharedPreferences? _prefs;

  // ── Inicialización ────────────────────────────────────────
  // Se llama desde main() antes de runApp. Cachea la instancia
  // para que el resto de la app lea el estado sin await.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get hasLinkedGoogleBefore => _prefs?.getBool(_keyGoogleLinked) ?? false;

  Future<void> markGoogleLinked() async {
    await _prefs?.setBool(_keyGoogleLinked, true);
  }

  String? get lastLoginFirstName => _prefs?.getString(_keyLastFirstName);
  String? get lastLoginLastName => _prefs?.getString(_keyLastLastName);
  String? get lastLoginAvatar => _prefs?.getString(_keyLastAvatar);

  Future<void> saveLastLoginProfile({
    required String firstName,
    String? lastName,
    String? avatar,
  }) async {
    await Future.wait([
      _prefs?.setString(_keyLastFirstName, firstName) ?? Future.value(),
      if (lastName != null) _prefs?.setString(_keyLastLastName, lastName) ?? Future.value(),
      if (avatar != null) _prefs?.setString(_keyLastAvatar, avatar) ?? Future.value(),
    ]);
  }
}
