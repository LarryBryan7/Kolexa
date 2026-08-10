// ============================================================
// app_theme.dart — Tema visual de la app
// ============================================================
// Define los colores, fuentes y estilos globales de Kolexa.
// Al centralizar aquí, cambiar el color primario afecta a toda
// la app sin tocar cada widget individualmente.
//
// Paleta oficial v2 (paleta ajustada, sincronizada desde Figma):
// violeta más apagado, fondo crema, sin dorado — el énfasis
// (montos, vencimientos) usa ámbar, y el éxito/asistencia usa verde.
// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  // ── Paleta de marca v2 ───────────────────────────────────
  static const Color primaryViolet = Color(0xFF5B4A9E); // Violeta (apagado)
  static const Color surfaceCream = Color(0xFFF7F6F3);  // Fondo crema
  static const Color ink = Color(0xFF1E1B29);           // Texto principal
  static const Color amber = Color(0xFF96650C);         // Énfasis (montos, vencimientos)
  static const Color successBg = Color(0xFFDCEEE1);     // Fondo de badges de éxito/presente
  static const Color successText = Color(0xFF1F6B44);   // Texto de badges de éxito/presente
  static const Color _error = Color(0xFFEF4444);        // Rojo

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: primaryViolet,
    brightness: Brightness.light,
    error: _error,
    surface: surfaceCream,
  ).copyWith(
    primary: primaryViolet,
    secondary: amber,
    onSecondary: Colors.white,
    onSurface: ink,
  );

  // ── Tema claro ───────────────────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true, // Material Design 3 (el más moderno en Flutter)
    fontFamily: 'Inter', // misma fuente que el sistema de marca en Figma
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: surfaceCream,

    // AppBar sin sombra y con fondo del color primario
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: primaryViolet,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Botones elevados con bordes redondeados
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryViolet,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52), // ancho completo, alto 52px
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Campos de texto con borde redondeado
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryViolet, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  // ── Tema oscuro ──────────────────────────────────────────
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryViolet,
      brightness: Brightness.dark,
      error: _error,
    ).copyWith(
      secondary: amber,
      onSecondary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
  );
}
