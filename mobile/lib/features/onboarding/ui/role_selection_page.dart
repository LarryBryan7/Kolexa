// ============================================================
// role_selection_page.dart — Pantalla de Selección de rol
// ============================================================
// Segundo paso del registro: el usuario elige cómo participa
// en el colegio (Padre/Madre, Docente, Director, Alumno).
// El rol seleccionado se marca con ícono sólido + borde blanco;
// los demás quedan en estilo outline (igual que en Figma).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/onboarding_page_dots.dart';

enum UserRole { parent, teacher, director, student }

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

// Mapea el enum de UI al string que usan OnboardingService/LoginPage —
// el mismo valor viaja persistido (SharedPreferences) y por navegación
// (extra de go_router), así que se resuelve una sola vez acá.
String _roleKey(UserRole role) {
  switch (role) {
    case UserRole.parent:
      return 'parent';
    case UserRole.teacher:
      return 'teacher';
    case UserRole.director:
      return 'director';
    case UserRole.student:
      return 'student';
  }
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  UserRole _selected = UserRole.parent;

  Future<void> _onContinuePressed() async {
    final roleKey = _roleKey(_selected);
    // El usuario completó el onboarding (seleccionó su rol). Marcamos el
    // flujo como completado para que en el próximo arranque la app vaya
    // directo al login, y persistimos el rol para que LoginPage sepa qué
    // mostrar incluso en ese arranque directo (sin pasar por acá de nuevo).
    await OnboardingService.instance.complete();
    await OnboardingService.instance.setSelectedRole(roleKey);

    if (!mounted) return;
    context.go(AppRouter.login, extra: {'role': roleKey});
  }

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OnboardingPageDots(activeIndex: 1),
                  const SizedBox(height: 32),
                  const Text(
                    '¿Cuál es tu rol?',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(
                    width: 210,
                    child: Text(
                      'Selecciona cómo participas en el colegio',
                      style: TextStyle(fontSize: 14, color: Color(0xBFFFFFFF)), // blanco @ 75%
                    ),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 138 / 132,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _RoleCard(
                          label: 'Padre /\nMadre',
                          filledIcon: Icons.favorite,
                          outlineIcon: Icons.favorite_border,
                          selected: _selected == UserRole.parent,
                          onTap: () => setState(() => _selected = UserRole.parent),
                        ),
                        _RoleCard(
                          label: 'Docente',
                          filledIcon: Icons.edit,
                          outlineIcon: Icons.edit_outlined,
                          selected: _selected == UserRole.teacher,
                          onTap: () => setState(() => _selected = UserRole.teacher),
                        ),
                        _RoleCard(
                          label: 'Director',
                          filledIcon: Icons.apartment,
                          outlineIcon: Icons.apartment_outlined,
                          selected: _selected == UserRole.director,
                          onTap: () => setState(() => _selected = UserRole.director),
                        ),
                        _RoleCard(
                          label: 'Alumno',
                          filledIcon: Icons.school,
                          outlineIcon: Icons.school_outlined,
                          selected: _selected == UserRole.student,
                          onTap: () => setState(() => _selected = UserRole.student),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryViolet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _onContinuePressed,
                      child: const Text(
                        'Continuar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.filledIcon,
    required this.outlineIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData filledIcon;
  final IconData outlineIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(24),
          border: selected ? Border.all(color: Colors.white, width: 2.5) : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? filledIcon : outlineIcon, color: Colors.white, size: selected ? 26 : 24),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
          ],
        ),
      ),
    );
  }
}
