import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Design system — "Obsidian"
//
// Near-black OLED surfaces with warm amber accent.
// Single accent color. Glass-like materiality on surfaces.
// Custom easing curves for premium motion.
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class AppColors {
  static const background    = Color(0xFF050507);
  static const surface       = Color(0xFF08080D);
  static const card          = Color(0xFF0D0D16);
  static const cardElevated  = Color(0xFF121220);

  static const accentPrimary = Color(0xFFD4A76A);
  static const accentPurple  = Color(0xFF8A7BC4);
  static const accentSoft    = Color(0x15D4A76A);

  static const border        = Color(0x0DFFFFFF);
  static const borderSubtle  = Color(0x07FFFFFF);
  static const borderGold    = Color(0x28D4A76A);

  static const textPrimary   = Color(0xFFECECF4);
  static const textSecondary = Color(0xFF6A6A80);
  static const textMuted     = Color(0xFF38384A);

  static const focusBorder   = Color(0xFFD4A76A);
  static const focusGlow     = Color(0x30D4A76A);

  static const error         = Color(0xFFD45B5B);
  static const errorSurface  = Color(0x20D45B5B);
  static const success       = Color(0xFF4FA872);
  static const warning       = Color(0xFFC9903A);

  static const playerOverlay = Color(0xEA050507);
  static const transparent   = Colors.transparent;

  static const skeleton      = Color(0xFF0C0C16);
  static const skeletonShine = Color(0xFF161624);

  static const glassBorder   = Color(0x0AFFFFFF);
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

  static const double tvH = 52.0;
  static const double tvV = 28.0;

  static const double radiusCard       = 14.0;
  static const double radiusInput      = 8.0;
  static const double radiusPill       = 24.0;
  static const double focusBorderWidth = 1.0;

  static const double iconSm  = 16.0;
  static const double iconMd  = 18.0;
  static const double iconLg  = 24.0;
}

abstract final class AppDurations {
  static const fast              = Duration(milliseconds: 80);
  static const medium            = Duration(milliseconds: 140);
  static const slow              = Duration(milliseconds: 240);
  static const press             = Duration(milliseconds: 100);
  static const focus             = Duration(milliseconds: 120);
  static const controlsAutoHide  = Duration(seconds: 3);
  static const historyFlushPeriod = Duration(seconds: 10);
}

abstract final class AppCurves {
  static const easeOut   = Cubic(0.23, 1.0, 0.32, 1.0);
  static const easeInOut = Cubic(0.77, 0.0, 0.175, 1.0);
}

abstract final class AppTheme {
  static const _fontFamily = 'DMSans';

  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.textTheme.copyWith(
        bodyLarge:   base.textTheme.bodyLarge?.copyWith(   fontFamily: _fontFamily, color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 14, height: 1.55),
        bodyMedium:  base.textTheme.bodyMedium?.copyWith(  fontFamily: _fontFamily, color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 13, height: 1.55),
        bodySmall:   base.textTheme.bodySmall?.copyWith(   fontFamily: _fontFamily, color: AppColors.textSecondary, fontWeight: FontWeight.w300, fontSize: 11, height: 1.45),
        labelLarge:  base.textTheme.labelLarge?.copyWith(  fontFamily: _fontFamily, color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: base.textTheme.labelMedium?.copyWith( fontFamily: _fontFamily, color: AppColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13),
        labelSmall:  base.textTheme.labelSmall?.copyWith(  fontFamily: _fontFamily, color: AppColors.textMuted,     fontWeight: FontWeight.w500, fontSize: 10, letterSpacing: 1.2),
        titleLarge:  base.textTheme.titleLarge?.copyWith(  fontFamily: _fontFamily, color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 20, letterSpacing: -0.8),
        titleMedium: base.textTheme.titleMedium?.copyWith( fontFamily: _fontFamily, color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 15, letterSpacing: -0.2),
        titleSmall:  base.textTheme.titleSmall?.copyWith(  fontFamily: _fontFamily, color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 13),
      ),
      colorScheme: const ColorScheme.dark(
        surface:   AppColors.surface,
        primary:   AppColors.accentPrimary,
        secondary: AppColors.accentPurple,
        error:     AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  AppColors.surface,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontFamily:    _fontFamily,
          color:         AppColors.textPrimary,
          fontWeight:    FontWeight.w500,
          fontSize:      15,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 18),
      ),
      cardTheme: CardTheme(
        color:     AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusCard)),
          side: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:   BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:   BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:   const BorderSide(color: AppColors.accentPrimary, width: 1.0),
        ),
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          fontFamily: _fontFamily,
          color:      AppColors.textMuted,
          fontWeight: FontWeight.w300,
          fontSize:   13,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color:     AppColors.border,
        thickness: 0.5,
        space:     0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:  AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
    );
  }
}
