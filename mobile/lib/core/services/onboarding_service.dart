// ============================================================
// onboarding_service.dart — Estado del onboarding (primera vez)
// ============================================================
// Controla si el flujo de bienvenida + selección de rol debe
// mostrarse o si ya fue completado.
//
// Regla de negocio:
//   - La PRIMERA vez que el usuario abre la app, ve el onboarding
//     (welcome → role-selection) y al completarlo se guarda una
//     bandera local.
//   - En arranques posteriores, si la bandera está activa, la app
//     va DIRECTAMENTE al login (el usuario "ya creó su cuenta").
//
// Implementación:
//   - Usa shared_preferences (clave-valor rápido, arranque instantáneo).
//   - Es un singleton (patrón igual que PushNotificationsService)
//     para que el router pueda leer el estado de forma SÍNCRONA
//     sin esperar un Future en cada build.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  // Clave en SharedPreferences. Versionada por si en el futuro
  // queremos resetear el onboarding (ej: nueva versión de la app).
  static const String _keyOnboardingCompleted = 'onboarding_completed_v1';

  // Instancia cacheada de SharedPreferences. Se inicializa en main()
  // ANTES de runApp para que `isCompleted` sea síncrono.
  SharedPreferences? _prefs;

  // ── Inicialización ────────────────────────────────────────
  // Se llama desde main() antes de runApp. Cachea la instancia
  // para que el resto de la app lea el estado sin await.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Estado ────────────────────────────────────────────────
  // true  → el usuario ya completó el onboarding → ir al login
  // false → primera vez → mostrar welcome
  //
  // Síncrono: si _prefs aún no está inicializado (no debería pasar
  // porque main() lo inicializa antes), asumimos "no completado"
  // para no romper el arranque.
  bool get isCompleted => _prefs?.getBool(_keyOnboardingCompleted) ?? false;

  // ── Acciones ──────────────────────────────────────────────
  // Marca el onboarding como completado. Se llama cuando el usuario
  // termina el flujo (selecciona su rol y presiona "Continuar").
  Future<void> complete() async {
    await _prefs?.setBool(_keyOnboardingCompleted, true);
  }

  // Útil para testing / debug: permite reiniciar el onboarding.
  Future<void> reset() async {
    await _prefs?.remove(_keyOnboardingCompleted);
  }
}
