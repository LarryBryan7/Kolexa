// ============================================================
// onboarding_page_dots.dart — Indicador de progreso (1/3, 2/3...)
// ============================================================
// Se usa en las pantallas de onboarding (Bienvenida, Selección
// de rol...) para mostrar en qué paso del flujo está el usuario.
// ============================================================

import 'package:flutter/material.dart';

class OnboardingPageDots extends StatelessWidget {
  const OnboardingPageDots({super.key, required this.activeIndex, this.count = 3});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 1 : 0.6),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
