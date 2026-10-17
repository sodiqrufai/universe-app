import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Read-only facts about this build, for feedback and error reports.
///
/// Call [AppInfo.init] once at startup (main.dart does). Before that, or if
/// the lookup fails, [version] is `unknown` rather than throwing.
class AppInfo {
  AppInfo._();

  static String _version = 'unknown';

  /// e.g. `1.0.0+3` (version + build number). Max ~40 chars, as the backend
  /// feedback endpoint expects.
  static String get version => _version;

  /// `android`, `ios`, `web`, `windows`, `macos`, `linux` or `fuchsia`.
  static String get platform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.trim();
      _version = build.isEmpty ? info.version : '${info.version}+$build';
    } catch (_) {
      // Keep 'unknown'.
    }
  }

  @visibleForTesting
  static void setVersionForTesting(String value) => _version = value;
}
