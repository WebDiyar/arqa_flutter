import 'package:flutter/material.dart';

/// Токены из макета задания (jobs.arqa.cc): страница, акцент и «чек».
abstract final class AppColors {
  static const background = Color(0xFFEEF1F5);
  static const ink = Color(0xFF1C2633);
  static const inkMuted = Color(0xFF5B6575);
  static const accent = Color(0xFF2D5BE3);
  static const surface = Color(0xFFFFFFFF);

  // состояния
  static const warning = Color(0xFFFFE8B3);
  static const onWarning = Color(0xFF5C4300);
  static const danger = Color(0xFFB3261E);

  // чек
  static const paper = Color(0xFFFFF8E1);
  static const paperInk = Color(0xFF2B2618);
  static const paperMuted = Color(0xFF7A7058);
  static const paperRule = Color(0xFFCDBF95);
}

abstract final class AppFonts {
  static const text = 'Golos Text';
  static const mono = 'JetBrains Mono';
  static const display = 'Unbounded';

  /// В JetBrains Mono нет знака ₸ — берём его из Golos Text.
  static const monoFallback = [text];
}

const _radius = BorderRadius.all(Radius.circular(12));

// ponytail: только светлая тема — макет «бумажный». Тёмная — второй набор
// AppColors + darkTheme в MaterialApp.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
  );
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: AppFonts.text,
    scaffoldBackgroundColor: AppColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.display,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
        textStyle: const TextStyle(
          fontFamily: AppFonts.text,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: _radius),
      extendedTextStyle: TextStyle(
        fontFamily: AppFonts.text,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        selectedBackgroundColor: AppColors.accent,
        selectedForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: _radius),
    ),
  );
}
