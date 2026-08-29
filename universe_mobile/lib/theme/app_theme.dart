import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// UniVerse design tokens.
/// Source of truth for every color used across the app — screens should
/// always reference AppColors, never hardcode a hex value, so the whole
/// app can be re-themed from this one file.
class AppColors {
  static const primary = Color(0xFF4F2CCF); // Deep UniVerse Purple
  static const primaryDark = Color(0xFF2D1B8C);
  static const secondary = Color(0xFF6D4AFF); // Secondary Purple
  static const lightPurple = Color(0xFFF0ECFF);
  static const veryLightPurple = Color(0xFFF7F5FF);

  static const background = Color(0xFFFAFAFC);
  static const surface = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF15152A);
  static const textSecondary = Color(0xFF6F7080);
  static const textMuted = Color(0xFF9999A8);
  static const border = Color(0xFFE8E8F0);

  static const success = Color(0xFF2E9B62);
  static const warning = Color(0xFFE9A23B);
  static const error = Color(0xFFD9534F);
  static const info = Color(0xFF4A7FE5);

  // Kept as an alias so existing screens using AppColors.accent
  // (badges, highlights) keep working without a find-and-replace;
  // maps to warning, the closest token in the new system.
  static const accent = warning;
}

/// Spacing scale — use these instead of arbitrary padding/margin numbers.
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// Radius scale — use these instead of arbitrary corner radii.
class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const card = 16.0;
  static const large = 20.0;
  static const pill = 999.0;
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}
