import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';

/// UniVerse design tokens.
/// Source of truth for every color used across the app — screens should
/// always reference AppColors, never hardcode a hex value, so the whole
/// app can be re-themed from this one file.
///
/// These are static GETTERS, not const fields, resolving against
/// ThemeController.instance.isDark (the user's chosen preference --
/// light/dark/system -- not raw platform brightness directly, so a manual
/// override actually works). Every existing call site (AppColors.primary,
/// AppColors.background, etc.) keeps working completely unchanged --
/// Dart's `ClassName.member` access syntax is identical for a const field
/// or a static getter. The one real implication: any `const` expression
/// that directly references an AppColors field is no longer valid, since a
/// getter isn't a compile-time constant -- that `const` keyword has to be
/// removed at each such call site, throughout this file and every screen
/// that uses one.
class AppColors {
  static bool get _isDark => ThemeController.instance.isDark;

  static Color get primary =>
      _isDark ? const Color(0xFF8B6DFF) : const Color(0xFF4F2CCF);
  static Color get primaryDark =>
      _isDark ? const Color(0xFF6D4AFF) : const Color(0xFF2D1B8C);
  static Color get secondary =>
      _isDark ? const Color(0xFF9B7FFF) : const Color(0xFF6D4AFF);
  static Color get lightPurple =>
      _isDark ? const Color(0xFF2A2440) : const Color(0xFFF0ECFF);
  static Color get veryLightPurple =>
      _isDark ? const Color(0xFF211D33) : const Color(0xFFF7F5FF);

  static Color get background =>
      _isDark ? const Color(0xFF121218) : const Color(0xFFFAFAFC);
  static Color get surface =>
      _isDark ? const Color(0xFF1C1C24) : const Color(0xFFFFFFFF);

  static Color get textPrimary =>
      _isDark ? const Color(0xFFF0F0F5) : const Color(0xFF15152A);
  static Color get textSecondary =>
      _isDark ? const Color(0xFFA8A8B8) : const Color(0xFF6F7080);
  static Color get textMuted =>
      _isDark ? const Color(0xFF75758A) : const Color(0xFF9999A8);
  static Color get border =>
      _isDark ? const Color(0xFF2E2E3A) : const Color(0xFFE8E8F0);

  static Color get success =>
      _isDark ? const Color(0xFF4CBE84) : const Color(0xFF2E9B62);
  static Color get warning =>
      _isDark ? const Color(0xFFF0B65C) : const Color(0xFFE9A23B);
  static Color get error =>
      _isDark ? const Color(0xFFE57975) : const Color(0xFFD9534F);
  static Color get info =>
      _isDark ? const Color(0xFF6E9BFF) : const Color(0xFF4A7FE5);

  // Kept as an alias so existing screens using AppColors.accent
  // (badges, highlights) keep working without a find-and-replace;
  // maps to warning, the closest token in the new system.
  static Color get accent => warning;
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
  /// Builds the ThemeData for the CURRENT AppColors state. Call this again
  /// (e.g. from a widget listening to ThemeController) whenever the
  /// preference changes -- it always reflects whatever AppColors currently
  /// resolves to, light or dark.
  static ThemeData current() {
    final isDark = ThemeController.instance.isDark;
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      textTheme:
          GoogleFonts.poppinsTextTheme(
            isDark ? ThemeData(brightness: Brightness.dark).textTheme : null,
          ).apply(
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
          side: BorderSide(color: AppColors.border),
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
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
