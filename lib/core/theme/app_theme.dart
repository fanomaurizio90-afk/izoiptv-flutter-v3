import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────────
  static const background    = Color(0xFF070709);  // OLED near-black, ghost of warmth
  static const surface       = Color(0xFF09090E);  // just above background
  static const card          = Color(0xFF0E0E17);  // card layer
  static const cardElevated  = Color(0xFF141422);  // elevated surface

  // ── Accent — champagne gold ───────────────────────────────────────────────────
  static const accentPrimary = Color(0xFFC8A058);  // warm gold
  static const accentPurple  = Color(0xFF9A7FD4);  // muted lilac (secondary)
  static const accentSoft    = Color(0x22C8A058);  // gold at 13%

  // ── Borders ──────────────────────────────────────────────────────────────────
  static const border        = Color(0x14FFFFFF);  // 8% white
  static const borderSubtle  = Color(0x09FFFFFF);  // 4% white
  static const borderGold    = Color(0x30C8A058);  // gold border

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFF0F0F6);  // soft off-white
  static const textSecondary = Color(0xFF8888A0);  // cooler grey
  static const textMuted     = Color(0xFF444456);  // deep muted

  // ── Focus: gold border + ambient glow ────────────────────────────────────────
  static const focusBorder      = Color(0xFFC8A058);
  static const focusBorderWidth = 1.5;
  static const focusGlow        = Color(0x38C8A058);  // stronger ambient

  // ── States ───────────────────────────────────────────────────────────────────
  static const error         = Color(0xFFE06060);
  static const errorSurface  = Color(0x25E06060);
  static const success       = Color(0xFF5AB87A);
  static const warning       = Color(0xFFD4963A);

  // ── Player ───────────────────────────────────────────────────────────────────
  static const playerOverlay = Color(0xEA070709);
  static const transparent   = Colors.transparent;

  // ── Skeleton shimmer ─────────────────────────────────────────────────────────
  static const skeleton      = Color(0xFF111119);
  static const skeletonShine = Color(0xFF1A1A26);
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

  // TV-safe insets — compensate for Fire Stick overscan (~5% of 1080p)
  static const double tvH = 52.0;
  static const double tvV = 28.0;

  // Border radii
  static const double radiusCard       = 10.0;
  static const double radiusInput      = 8.0;
  static const double radiusPill       = 24.0;
  static const double focusBorderWidth = 1.5;

  // Icon sizes
  static const double iconSm  = 16.0;
  static const double iconMd  = 18.0;
  static const double iconLg  = 24.0;
}

abstract final class AppDurations {
  static const fast              = Duration(milliseconds: 100);
  static const medium            = Duration(milliseconds: 160);
  static const slow              = Duration(milliseconds: 280);
  static const press             = Duration(milliseconds: 120);
  static const focus             = Duration(milliseconds: 140);
  static const controlsAutoHide  = Duration(seconds: 3);
  static const historyFlushPeriod = Duration(seconds: 10);
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
        titleLarge:  base.textTheme.titleLarge?.copyWith(  fontFamily: _fontFamily, color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 20, letterSpacing: -0.5),
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
          fontFamily: _fontFamily,
          color:      AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize:   15,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 18),
      ),
      cardTheme: const CardTheme(
        color:     AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusCard)),
          side:         BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:        true,
        fillColor:     AppColors.card,
        border:        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:   const BorderSide(color: AppColors.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:   const BorderSide(color: AppColors.border, width: 0.5),
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
          side:         const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
    );
  }
}
