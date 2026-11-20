import 'package:flutter/material.dart';

class AppColors {
  static const rose = Color(0xFFE75480);
  static const roseSoft = Color(0xFFF8A5C2);
  static const lavender = Color(0xFF9B7EDE);
  static const lavenderSoft = Color(0xFFD9CCF5);
  static const cream = Color(0xFFFFF7FA);
  static const peach = Color(0xFFFFC2A8);
  static const mint = Color(0xFF8FD9C1);
  static const ink = Color(0xFF3B2A3F);
  static const inkSoft = Color(0xFF7A6A80);

  static const protein = Color(0xFF9B7EDE);
  static const carbs = Color(0xFFFFB457);
  static const fat = Color(0xFFE75480);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.rose,
    brightness: Brightness.light,
    primary: AppColors.rose,
    secondary: AppColors.lavender,
    surface: AppColors.cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 28),
      titleLarge: TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 20),
      titleMedium: TextStyle(
          fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.ink, fontSize: 14),
      bodySmall: TextStyle(color: AppColors.inkSoft, fontSize: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.ink,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 20),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: AppColors.rose.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rose,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.rose,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.roseSoft, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lavenderSoft)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lavenderSoft)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.roseSoft.withValues(alpha: 0.5),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: AppColors.lavenderSoft,
  );
}

const kGradient = LinearGradient(
  colors: [AppColors.rose, AppColors.lavender],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
