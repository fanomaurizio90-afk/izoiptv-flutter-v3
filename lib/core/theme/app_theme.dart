import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds — deep cyber space
  static const background    = Color(0xFF030308);
  static const surface       = Color(0xFF050510);
  static const card          = Color(0xFF0A0A14);

  // Brand accents
  static const accentPrimary = Color(0xFF00F0FF);   // electric cyan
  static const accentPurple  = Color(0xFFA855F7);   // violet
  static const accentSoft    = Color(0x1A00F0FF);   // cyan 10% — subtle card bg
  static const accentBright  = Color(0xFF00F0FF);

  // Borders — cyan-tinted
  static const border        = Color(0x2600F0FF);   // cyan 15%
  static const borderSubtle  = Color(0x1200F0FF);   // cyan 7%

  // Text hierarchy
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);   // white 60%
  static const textMuted     = Color(0x4DFFFFFF);   // white 30%

  // Interaction
  static const focusBorder   = Color(0xFF00F0FF);   // cyan
  static const focusGlow     = Color(0x4000F0FF);   // cyan glow 25%

  // Semantic
  static const error         = Color(0xFFF87171);
  static const errorSurface  = Color(0x33F87171);
  static const success       = Color(0xFF22C55E);
  static const warning       = Color(0xFFF59E0B);

  // Player
  static const playerOverlay = Color(0xEA030308);
  static const transparent   = Colors.transparent;
}

abstract final class AppSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double xl2 = 24.0;
  static const double xl3 = 32.0;
  static const double xl4 = 40.0;
  static const double xl5 = 48.0;
  static const double xl6 = 64.0;
  static const double radiusCard       = 8.0;
  static const double radiusInput      = 6.0;
  static const double radiusPill       = 0.0;
  static const double focusBorderWidth = 1.0;
  static const double focusBlurRadius  = 0.0;
  static const double iconSm  = 18.0;
  static const double iconMd  = 18.0;
  static const double iconLg  = 24.0;
}

abstract final class AppDurations {
  static const fast              = Duration(milliseconds: 100);
  static const medium            = Duration(milliseconds: 150);
  static const slow              = Duration(milliseconds: 250);
  static const controlsAutoHide = Duration(seconds: 3);
  static const volumeFadeDelay  = Duration(milliseconds: 800);
  static const reconnectBase    = Duration(seconds: 2);
  static const historyFlushPeriod = Duration(seconds: 10);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentPurple,
        error: AppColors.error,
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge:   const TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 14),
        bodyMedium:  const TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 13),
        bodySmall:   const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w300, fontSize: 11),
        labelLarge:  const TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w400, fontSize: 14),
        labelMedium: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13),
        labelSmall:  const TextStyle(color: AppColors.textMuted,     fontWeight: FontWeight.w400, fontSize: 11),
        titleLarge:  const TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w600, fontSize: 16),
        titleMedium: const TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w600, fontSize: 14),
        titleSmall:  const TextStyle(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 13),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 18),
      ),
      cardTheme: const CardTheme(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusCard)),
          side: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w300, fontSize: 13),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 0.5,
        space: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPrimary,
      ),
    );
  }
}
