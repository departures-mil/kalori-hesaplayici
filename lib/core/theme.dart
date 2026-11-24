import 'package:flutter/material.dart';

import 'look.dart';

/// Uygulama renkleri. v1.1.0'dan beri seçili Falcon şemasından gelir
/// (Ayarlar → Görünüm); "klasik" şeması açık modda eski renklerin birebir aynısıdır.
class AppColors {
  static FcPalette get _p => FcLook.instance.palette;

  static Color get rose => _p.rose;
  static Color get roseSoft => _p.roseSoft;
  static Color get lavender => _p.lavender;
  static Color get lavenderSoft => _p.lavenderSoft;
  static Color get cream => _p.bg;
  static Color get peach => _p.peach;
  static Color get mint => _p.mint;
  static Color get ink => _p.text;
  static Color get inkSoft => _p.muted;
  static Color get card => _p.panel;

  static Color get protein => _p.lavender;
  static Color get carbs => _p.carbs;
  static Color get fat => _p.rose;
}

/// Arapçada Noto Sans Arabic, diğer dillerde Inter (ikisi de uygulamaya gömülü).
String fontFor(String lang) => lang == 'ar' ? 'NotoSansArabic' : 'Inter';
List<String> fontFallbackFor(String lang) =>
    lang == 'ar' ? const ['Inter'] : const ['NotoSansArabic'];

ThemeData buildTheme({String lang = 'tr'}) {
  final p = FcLook.instance.palette;
  final brightness = p.dark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent2,
    surface: p.panel,
    onSurface: p.text,
    error: p.danger,
  );
  final ink = p.text;
  // Bileşen metin stilleri yazı tipini textTheme'den almaz; Inter / Noto Sans Arabic açıkça verilir.
  final ff = fontFor(lang);
  final fb = fontFallbackFor(lang);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: fontFor(lang),
    fontFamilyFallback: fontFallbackFor(lang),
    textTheme: TextTheme(
      headlineMedium:
          TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 28),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 20),
      titleMedium:
          TextStyle(fontWeight: FontWeight.w600, color: ink, fontSize: 16),
      bodyLarge: TextStyle(color: ink, fontSize: 16),
      bodyMedium: TextStyle(color: ink, fontSize: 14),
      bodySmall: TextStyle(color: p.muted, fontSize: 12),
    ),
    iconTheme: IconThemeData(color: ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p['topbar-bg'],
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: ink,
      centerTitle: false,
      titleTextStyle:
          TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 18, fontFamily: ff, fontFamilyFallback: fb),
    ),
    cardTheme: CardThemeData(
      color: p.panel,
      elevation: 0,
      shadowColor: p.accent.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p['modal-bg'],
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p['modal-border'])),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p['modal-bg'],
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: const Size.fromHeight(52),
        textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: ff, fontFamilyFallback: fb),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.accent,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: p['accent-line'], width: 1.5),
        textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: ff, fontFamilyFallback: fb),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: TextStyle(fontWeight: FontWeight.w600, fontFamily: ff, fontFamilyFallback: fb)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600, fontFamily: ff, fontFamilyFallback: fb)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.panel,
      selectedColor: p['active-1'],
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(color: ink, fontFamily: ff, fontFamilyFallback: fb),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.panel,
      labelStyle: TextStyle(color: p.muted),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.lavenderSoft)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.lavenderSoft)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p['focus'], width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.panel,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p['active-1'],
      labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink, fontFamily: ff, fontFamilyFallback: fb)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p['toast-bg'],
      contentTextStyle: TextStyle(color: p['toast-text'], fontFamily: ff, fontFamilyFallback: fb),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p['toast-line'])),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p['bar-track'],
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : null),
    ),
    dividerColor: p.border,
  );
}

LinearGradient get kGradient => LinearGradient(
      colors: FcLook.instance.palette.gradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
