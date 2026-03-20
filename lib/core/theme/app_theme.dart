import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background    = Color(0xFF080808);
  static const surface       = Color(0xFF0F0F0F);
  static const card          = Color(0xFF111111);
  static const border        = Color(0xFF222222);
  static const accentPrimary = Color(0xFFFFFFFF);
  static const accentSoft    = Color(0xFF333333);
  static const accentBright  = Color(0xFFFFFFFF);
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textMuted     = Color(0xFF444444);
  static const focusBorder   = Color(0xFFFFFFFF);
  static const error         = Color(0xFFFF4F4F);
  static const errorSurface  = Color(0xFF2A1010);
  static const success       = Color(0xFF22C55E);
  static const warning       = Color(0xFFF59E0B);
  static const playerOverlay = Color(0xE6080808);
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
  static const double radiusInput      = 0.0;
  static const double radiusPill       = 0.0;
  static const double focusBorderWidth = 1.0;
  static const double focusBlurRadius  = 0.0;
  static const double iconSm  = 18.0;
  static const double iconMd  = 18.0;
  static const double iconLg  = 24.0;
}

abstract final class AppDurations {
  static const fast              = Duration(milliseconds: 100);
  static const medium            = Duration(milliseconds: 100);
  static const slow              = Duration(milliseconds: 200);
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
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        bodyLarge:   GoogleFonts.dmSans(color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 14),
        bodyMedium:  GoogleFonts.dmSans(color: AppColors.textPrimary,   fontWeight: FontWeight.w300, fontSize: 13),
        bodySmall:   GoogleFonts.dmSans(color: AppColors.textSecondary, fontWeight: FontWeight.w300, fontSize: 11),
        labelLarge:  GoogleFonts.dmSans(color: AppColors.textPrimary,   fontWeight: FontWeight.w400, fontSize: 14),
        labelMedium: GoogleFonts.dmSans(color: AppColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13),
        labelSmall:  GoogleFonts.dmSans(color: AppColors.textMuted,     fontWeight: FontWeight.w400, fontSize: 11),
        titleLarge:  GoogleFonts.dmSans(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 16),
        titleMedium: GoogleFonts.dmSans(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 14),
        titleSmall:  GoogleFonts.dmSans(color: AppColors.textPrimary,   fontWeight: FontWeight.w500, fontSize: 13),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 18),
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
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.accentPrimary, width: 0.5),
          borderRadius: BorderRadius.zero,
        ),
        hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted, fontWeight: FontWeight.w300, fontSize: 13),
        labelStyle: GoogleFonts.dmSans(color: AppColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}
