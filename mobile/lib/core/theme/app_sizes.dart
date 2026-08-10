// ============================================================
// app_sizes.dart — Sistema de tamaños responsivos (breakpoints)
// ============================================================
// Reemplaza el enfoque experimental de escalado dinámico continuo
// (factor `* s` calculado en cada build) por escalones fijos de
// diseño, inyectados vía ThemeData.extensions.
//
// Dos escalones:
//   - AppSizes.compact → pantallas estándar (base 360dp)
//   - AppSizes.medium  → pantallas grandes (>= 400dp, ej. 411dp)
//
// Uso en un widget:
//   final sizes = Theme.of(context).extension<AppSizes>()!;
//   Text('Hola', style: TextStyle(fontSize: sizes.titleHorizontal));
// ============================================================

import 'package:flutter/material.dart';

class AppSizes extends ThemeExtension<AppSizes> {
  const AppSizes._({
    required this.titleHorizontal,
    required this.textFecha,
    required this.avatarLarge,
    required this.textNombreHijo,
    required this.textSubtitulo,
    required this.iconChevron,
    required this.circleIconNovedades,
    required this.glyphNovedades,
    required this.textLabelCard,
    required this.textValueCard,
    required this.circleIconAccesos,
    required this.glyphAccesos,
    required this.textLabelAccesos,
    required this.iconBottomNav,
    required this.textLabelBottomNav,
    required this.childSwitcherCircle,
    required this.cardPadding,
  });

  // ── Header ─────────────────────────────────────────────
  final double titleHorizontal;   // "Hola, X"
  final double textFecha;         // "Lunes 22 de junio"

  // ── Tarjeta hijo ───────────────────────────────────────
  final double avatarLarge;       // avatar circular grande
  final double textNombreHijo;    // "Sofía Arias"
  final double textSubtitulo;     // "Sección Girasoles · 4 años"

  // ── Compartido entre tarjetas ────────────────────────────
  final double iconChevron;       // '›' de navegación

  // ── Novedades / Pendientes ───────────────────────────────
  final double circleIconNovedades; // fondo circular del ícono
  final double glyphNovedades;      // ícono dentro del círculo
  final double textLabelCard;       // "Llegada" / "ver todo en calendario"
  final double textValueCard;       // "temprano" / título de tarjeta (11px)

  // ── Accesos rápidos ──────────────────────────────────────
  final double circleIconAccesos;
  final double glyphAccesos;
  final double textLabelAccesos;

  // ── Bottom nav ───────────────────────────────────────────
  final double iconBottomNav;
  final double textLabelBottomNav;

  // ── Child switcher (header) ───────────────────────────────
  final double childSwitcherCircle; // círculo grande (seleccionado)

  // ── Layout ───────────────────────────────────────────────
  final double cardPadding; // padding horizontal del scaffold

  // ── Escalón: pantallas estándar (base 360dp) ──────────────
  static const compact = AppSizes._(
    titleHorizontal: 22,
    textFecha: 13,
    avatarLarge: 55,
    textNombreHijo: 14.5,
    textSubtitulo: 11,
    iconChevron: 20,
    circleIconNovedades: 28,
    glyphNovedades: 14,
    textLabelCard: 10,
    textValueCard: 11,
    circleIconAccesos: 24,
    glyphAccesos: 13,
    textLabelAccesos: 10,
    iconBottomNav: 19,
    textLabelBottomNav: 8.5,
    childSwitcherCircle: 36,
    cardPadding: 24,
  );

  // ── Escalón: pantallas grandes (ancho >= 400dp) ───────────
  static const medium = AppSizes._(
    titleHorizontal: 25,
    textFecha: 14,
    avatarLarge: 60, // redondeado
    textNombreHijo: 16,
    textSubtitulo: 13,
    iconChevron: 16,
    circleIconNovedades: 32,
    glyphNovedades: 16,
    textLabelCard: 13,
    textValueCard: 13,
    circleIconAccesos: 35,
    glyphAccesos: 17,
    textLabelAccesos: 13,
    iconBottomNav: 19,
    textLabelBottomNav: 10,
    childSwitcherCircle: 41.1,
    cardPadding: 24, // fijo: el margen del scaffold no crece con el breakpoint
  );

  @override
  AppSizes copyWith({
    double? titleHorizontal,
    double? textFecha,
    double? avatarLarge,
    double? textNombreHijo,
    double? textSubtitulo,
    double? iconChevron,
    double? circleIconNovedades,
    double? glyphNovedades,
    double? textLabelCard,
    double? textValueCard,
    double? circleIconAccesos,
    double? glyphAccesos,
    double? textLabelAccesos,
    double? iconBottomNav,
    double? textLabelBottomNav,
    double? childSwitcherCircle,
    double? cardPadding,
  }) {
    return AppSizes._(
      titleHorizontal: titleHorizontal ?? this.titleHorizontal,
      textFecha: textFecha ?? this.textFecha,
      avatarLarge: avatarLarge ?? this.avatarLarge,
      textNombreHijo: textNombreHijo ?? this.textNombreHijo,
      textSubtitulo: textSubtitulo ?? this.textSubtitulo,
      iconChevron: iconChevron ?? this.iconChevron,
      circleIconNovedades: circleIconNovedades ?? this.circleIconNovedades,
      glyphNovedades: glyphNovedades ?? this.glyphNovedades,
      textLabelCard: textLabelCard ?? this.textLabelCard,
      textValueCard: textValueCard ?? this.textValueCard,
      circleIconAccesos: circleIconAccesos ?? this.circleIconAccesos,
      glyphAccesos: glyphAccesos ?? this.glyphAccesos,
      textLabelAccesos: textLabelAccesos ?? this.textLabelAccesos,
      iconBottomNav: iconBottomNav ?? this.iconBottomNav,
      textLabelBottomNav: textLabelBottomNav ?? this.textLabelBottomNav,
      childSwitcherCircle: childSwitcherCircle ?? this.childSwitcherCircle,
      cardPadding: cardPadding ?? this.cardPadding,
    );
  }

  // Interpola cada campo con un Tween<double>, para que un eventual
  // AnimatedTheme (o el cambio de breakpoint en caliente al rotar/
  // redimensionar la ventana) transicione con suavidad en vez de saltar.
  static double _t(double begin, double end, double t) =>
      Tween<double>(begin: begin, end: end).transform(t);

  @override
  AppSizes lerp(ThemeExtension<AppSizes>? other, double t) {
    if (other is! AppSizes) return this;
    return AppSizes._(
      titleHorizontal: _t(titleHorizontal, other.titleHorizontal, t),
      textFecha: _t(textFecha, other.textFecha, t),
      avatarLarge: _t(avatarLarge, other.avatarLarge, t),
      textNombreHijo: _t(textNombreHijo, other.textNombreHijo, t),
      textSubtitulo: _t(textSubtitulo, other.textSubtitulo, t),
      iconChevron: _t(iconChevron, other.iconChevron, t),
      circleIconNovedades: _t(circleIconNovedades, other.circleIconNovedades, t),
      glyphNovedades: _t(glyphNovedades, other.glyphNovedades, t),
      textLabelCard: _t(textLabelCard, other.textLabelCard, t),
      textValueCard: _t(textValueCard, other.textValueCard, t),
      circleIconAccesos: _t(circleIconAccesos, other.circleIconAccesos, t),
      glyphAccesos: _t(glyphAccesos, other.glyphAccesos, t),
      textLabelAccesos: _t(textLabelAccesos, other.textLabelAccesos, t),
      iconBottomNav: _t(iconBottomNav, other.iconBottomNav, t),
      textLabelBottomNav: _t(textLabelBottomNav, other.textLabelBottomNav, t),
      childSwitcherCircle: _t(childSwitcherCircle, other.childSwitcherCircle, t),
      cardPadding: _t(cardPadding, other.cardPadding, t),
    );
  }
}
