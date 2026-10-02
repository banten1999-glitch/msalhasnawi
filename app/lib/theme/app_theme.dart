import 'package:flutter/material.dart';

/// ألوان الهوية المأخوذة من الشعار.
abstract final class AppColors {
  static const pomegranate = Color(0xFFA00B1E);
  static const pomegranateDark = Color(0xFF7E0817);
  static const pomegranateLight = Color(0xFFFBE9EC);
  static const leaf = Color(0xFF1F6B2C);
  static const leafLight = Color(0xFFE5F1E9);
  static const ivory = Color(0xFFFAF6EE);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFD9CFC1);
  static const ink = Color(0xFF1C1714);
  static const inkSecondary = Color(0xFF5E554E);
  static const inkMuted = Color(0xFF6F655D);
  static const amber = Color(0xFF8A4B00);
  static const amberLight = Color(0xFFFDF0D5);
  static const info = Color(0xFF1D4F91);
  static const infoLight = Color(0xFFE6EEF8);
  static const error = Color(0xFFB42318);
}

abstract final class AppFonts {
  static const body = 'IBMPlexSansArabic';
  static const display = 'ReadexPro';
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.pomegranate,
    primary: AppColors.pomegranate,
    secondary: AppColors.leaf,
    surface: AppColors.surface,
    error: AppColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ivory,
    fontFamily: AppFonts.body,
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineSmall: TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700, color: AppColors.ink),
      titleLarge: TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 15, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
