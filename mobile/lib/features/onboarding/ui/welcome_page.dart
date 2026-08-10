// ============================================================
// welcome_page.dart — Pantalla de Bienvenida (splash de marca)
// ============================================================
// Primera pantalla que ve un usuario sin sesión, justo después
// del splash nativo. Desde acá se bifurca el flujo:
//   - "Crear cuenta gratis" → selección de rol (registro)
//   - "Ya tengo cuenta"     → login
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kolexa_logo.dart';
import 'widgets/onboarding_page_dots.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryViolet,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const OnboardingPageDots(activeIndex: 0),
                  const Spacer(flex: 3),

                  // ── Logo "K" — cinta blanca, sistema de marca v2 ──
                  const KolexaLogo(height: 53),
                  const SizedBox(height: 24),

                  const Text(
                    'Bienvenido a Kolexa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Todo lo que pasa en el día de tu hijo, en un solo lugar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),

                  const Spacer(flex: 4),

                  // ── Crear cuenta → selección de rol ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryViolet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => context.go(AppRouter.roleSelection),
                      child: const Text(
                        'Crear cuenta gratis',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Ya tengo cuenta → login ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => context.go(AppRouter.login),
                      child: const Text(
                        'Ya tengo cuenta',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
