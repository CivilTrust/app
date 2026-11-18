import 'package:flutter/material.dart';

/// Design tokens for CivilTrust. Colors are chosen for WCAG AA contrast on
/// white surfaces; status tones are kept distinct so a legal notice, simulated
/// data and an error never share the same visual treatment.
abstract final class AppColors {
  static const primary = Color(0xff1e3a8a); // navy — trust, legal
  static const primaryContainer = Color(0xffdbe4ff);
  static const accent = Color(0xff0d9488); // teal — continuity with v1 brand
  static const accentContainer = Color(0xffccfbf1);
  static const background = Color(0xfff8fafc);
  static const surface = Colors.white;
  static const border = Color(0xffd8dee8);
  static const ink = Color(0xff0f172a);
  static const inkMuted = Color(0xff475569);
}

/// Semantic tone for banners, chips and notices.
enum AppTone {
  info(
    Color(0xff0369a1),
    Color(0xfff0f9ff),
    Color(0xffbae6fd),
    Icons.info_outline,
  ),
  success(
    Color(0xff15803d),
    Color(0xfff0fdf4),
    Color(0xffbbf7d0),
    Icons.check_circle_outline,
  ),
  warning(
    Color(0xffb45309),
    Color(0xfffffbeb),
    Color(0xfffcd34d),
    Icons.warning_amber_rounded,
  ),
  danger(
    Color(0xffb91c1c),
    Color(0xfffef2f2),
    Color(0xfffecaca),
    Icons.error_outline,
  ),

  /// Only for simulated/demo data, never for real warnings.
  mock(
    Color(0xff6d28d9),
    Color(0xfff5f3ff),
    Color(0xffddd6fe),
    Icons.science_outlined,
  );

  const AppTone(this.foreground, this.background, this.border, this.icon);
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
}

abstract final class AppBreakpoints {
  /// Below this width the app uses a bottom navigation bar.
  static const rail = 840.0;

  /// From this width the rail shows labels next to icons.
  static const extendedRail = 1200.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryContainer,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.accentContainer,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    error: AppTone.danger.foreground,
    outline: AppColors.border,
  );
  final radius = BorderRadius.circular(10);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  const text = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(fontSize: 15, height: 1.45),
    bodySmall: TextStyle(fontSize: 13, height: 1.4),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 2),
      errorBorder: border(AppTone.danger.foreground),
      focusedErrorBorder: border(AppTone.danger.foreground, 2),
      helperMaxLines: 3,
      errorMaxLines: 3,
      labelStyle: const TextStyle(color: AppColors.inkMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.inkMuted,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryContainer,
      selectedIconTheme: IconThemeData(color: AppColors.primary),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}
