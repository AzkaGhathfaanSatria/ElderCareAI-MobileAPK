import 'package:flutter/material.dart';

/// Token warna disalin dari frontend web (`src/index.css`, blok @theme).
class AppColors {
  AppColors._();

  static const ink = Color(0xFF3B2A1C);
  static const inkSoft = Color(0xFF5C4530);
  static const paper = Color(0xFFFAF5EE);
  static const surface = Color(0xFFFFFBF6);
  static const accent = Color(0xFFC1802F);
  static const accentDark = Color(0xFF935C1E);
  static const danger = Color(0xFFB0432C);
  static const warn = Color(0xFFC99A3D);
  static const safe = Color(0xFF74804A);
  static const muted = Color(0xFF7D6B57);
  static const border = Color(0xFFE9DCC9);
  static const sidebar = Color(0xFF2A1C12);
}

/// Font serif sistem untuk judul (web memakai Fraunces).
const String kSerif = 'serif';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );

  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.ink, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0x99C1802F),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accentDark),
    ),
  );
}
