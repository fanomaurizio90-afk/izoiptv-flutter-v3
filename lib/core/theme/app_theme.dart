import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background    = Color(0xFF080808);
  static const surface       = Color(0xFF0F0F0F);
  static const card          = Color(0xFF141414);
  static const cardElevated  = Color(0xFF1A1A1A);

  static const accentPrimary = Color(0xFF00F0FF);
  static const accentPurple  = Color(0xFFA855F7);
  static const accentSoft    = Color(0x1400F0FF);

  static const border        = Color(0xFF2A2A2A);
  static const borderSubtle  = Color(0xFF1A1A1A);

  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted     = Color(0x4DFFFFFF);

  // Focus: 1px white border only — no glow
  static const focusBorder   = Color(0xFFFFFFFF);

  static const error         = Color(0xFFF87171);
  static const errorSurface  = Color(0x33F87171);
  static const success       = Color(0xFF22C55E);
  static const warning       = Color(0xFFF59E0B);

  static const playerOverlay = Color(0xEA080808);
  static const transparent   = Colors.transparent;
  static const skeleton      = Color(0xFF1A1A1A);
  static const skeletonShine = Color(0xFF2C2C2C);
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
  // TV-safe insets: compensate for Fire Stick overscan (≈5% of 1080p screen)
  static const double tvH = 48.0;  // horizontal edge padding on TV screens
  static const double tvV = 24.0;  // extra vertical inset for TV overscan
  static const double radiusCard       = 8.0;
  static const double radiusInput      = 6.0;
  static const double radiusPill       = 20.0;
  static const double focusBorderWidth = 1.0;
  static const double iconSm  = 16.0;
  static const double iconMd  = 18.0;
  static const double iconLg  = 24.0;
}

abstract final class AppDurations {
  static const fast              = Duration(milliseconds: 100);
  static const medium            = Duration(milliseconds: 150);
  static const slow              = Duration(milliseconds: 250);
  static const press             = Duration(milliseconds: 100);
  static const controlsAutoHide  = Duration(seconds: 3);
  static const historyFlushPeriod = Duration(seconds: 10);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.textTheme.copyWith(
        bodyLarge:   base.textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 14, height: 1.5),
        bodyMedium:  base.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 13, height: 1.5),
        bodySmall:   base.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w300, fontSize: 11, height: 1.4),
        labelLarge:  base.textTheme.labelLarge?.copyWith(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: base.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13),
        labelSmall:  base.textTheme.labelSmall?.copyWith(color: AppColors.textMuted,   fontWeight: FontWeight.w400, fontSize: 11, letterSpacing: 0.5),
        titleLarge:  base.textTheme.titleLarge?.copyWith(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 16),
        titleMedium: base.textTheme.titleMedium?.copyWith(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 14),
        titleSmall:  base.textTheme.titleSmall?.copyWith(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 13),
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
          color:      AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize:   14,
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
        filled:      true,
        fillColor:   AppColors.card,
        border:      const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border, width: 0.5)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border, width: 0.5)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary, width: 1)),
        hintStyle:   base.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w300, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color:     AppColors.border,
        thickness: 0.5,
        space:     0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.textPrimary,
      ),
    );
  }
}
