import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

/// Holds the user's chosen theme preference (light / dark / system) and
/// whatever the CURRENT effective brightness resolves to, given that
/// choice. AppColors reads `ThemeController.isDark` (not raw platform
/// brightness directly), so a manual override actually overrides --
/// picking "Light" keeps the app light even if the phone's system setting
/// is dark, and vice versa. "System" falls back to following the device.
///
/// A plain ChangeNotifier, not a new state-management dependency -- this
/// app uses StatefulWidget/setState throughout, so this matches that
/// existing pattern rather than introducing Provider/Riverpod for one
/// feature.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  bool get isDark {
    if (_mode == ThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  /// Loads the persisted choice at app startup. Call once, before runApp,
  /// same as any other one-time init this app already does.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    switch (stored) {
      case 'light':
        _mode = ThemeMode.light;
      case 'dark':
        _mode = ThemeMode.dark;
      default:
        _mode = ThemeMode.system;
    }
    // Rebuilds whenever the OS-level setting flips while in "System" mode,
    // so the app follows along live instead of only on next launch.
    PlatformDispatcher.instance.onPlatformBrightnessChanged = () {
      if (_mode == ThemeMode.system) notifyListeners();
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_prefsKey, 'light');
      case ThemeMode.dark:
        await prefs.setString(_prefsKey, 'dark');
      case ThemeMode.system:
        await prefs.setString(_prefsKey, 'system');
    }
  }
}
