import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniVerse',
      // Dark mode is intentionally not wired yet — AppColors is still
      // fully static/light-only (no brightness-aware values), so
      // referencing a system dark theme here without one would either
      // crash (no AppTheme.dark() exists) or, if a token theme were
      // added without also making AppColors context-aware, render
      // near-black text (AppColors.textPrimary) on a dark background
      // everywhere a screen sets color explicitly rather than through
      // Theme.of(context) — illegible, and worse than not having dark
      // mode at all. This was already flagged as deferred until the
      // Language settings work lands, since both touch AppColors/
      // theming and are meant to happen in the same coordinated pass.
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
