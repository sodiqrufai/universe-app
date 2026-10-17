import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';

/// Thin product-analytics wrapper. A complete no-op unless the app was built
/// with `--dart-define=ANALYTICS_KEY=...`.
///
/// Sends to a PostHog-compatible `/capture/` endpoint (key-based, no SDK).
/// Optional `--dart-define=ANALYTICS_HOST=https://eu.i.posthog.com` for the EU
/// region (default is the US host).
///
/// Privacy rules, enforced here:
///  * the visitor id is a random id created on this device, never the user id,
///    email or any account detail;
///  * property values are limited to short strings/numbers/booleans;
///  * properties whose names look sensitive (token, password, message, email,
///    phone, matric, id photo...) are dropped.
class Telemetry {
  Telemetry._();

  static const String _key = String.fromEnvironment('ANALYTICS_KEY');
  static const String _host = String.fromEnvironment(
    'ANALYTICS_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  static bool _enabled = false;
  static String? _distinctId;
  static http.Client? _client;
  static String _keyForTesting = '';

  static bool get isEnabled => _enabled;

  /// Call once at startup. [client] must be a plain client created OUTSIDE the
  /// app-wide resilient zone (see main.dart) so analytics traffic never
  /// triggers retries or the "waking up" banner.
  static Future<void> init({required http.Client client}) async {
    final key = _effectiveKey;
    if (key.isEmpty) return;
    try {
      _client = client;
      _distinctId = await _loadOrCreateId();
      _enabled = true;
    } catch (_) {
      _enabled = false;
    }
  }

  static String get _effectiveKey =>
      _keyForTesting.isNotEmpty ? _keyForTesting : _key;

  /// Records an event. Never throws, never blocks the caller.
  static void track(String event, [Map<String, Object?>? props]) {
    if (!_enabled) return;
    try {
      unawaited(_send(event, props));
    } catch (_) {}
  }

  static Future<void> _send(String event, Map<String, Object?>? props) async {
    final client = _client;
    final id = _distinctId;
    if (client == null || id == null) return;
    try {
      final body = jsonEncode({
        'api_key': _effectiveKey,
        'event': event,
        'distinct_id': id,
        'properties': {
          ...sanitize(props),
          r'$lib': 'universe_mobile',
          'app_version': AppInfo.version,
          'platform': AppInfo.platform,
        },
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      await client
          .post(
            Uri.parse('$_host/capture/'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Analytics must never affect the app.
    }
  }

  static final RegExp _sensitiveName = RegExp(
    r'token|password|passwd|secret|message|text|body|content|email|phone|'
    r'matric|photo|document|address|name|otp|code',
    caseSensitive: false,
  );

  /// Keeps only safe, small values. Exposed for tests.
  @visibleForTesting
  static Map<String, Object> sanitize(Map<String, Object?>? props) {
    final out = <String, Object>{};
    if (props == null) return out;
    props.forEach((k, v) {
      if (v == null || _sensitiveName.hasMatch(k)) return;
      if (v is bool || v is num) {
        out[k] = v;
      } else if (v is String) {
        out[k] = v.length > 100 ? v.substring(0, 100) : v;
      }
    });
    return out;
  }

  static Future<String> _loadOrCreateId() async {
    const prefsKey = 'analytics_visitor_id';
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(prefsKey);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await prefs.setString(prefsKey, id);
    }
    return id;
  }

  @visibleForTesting
  static void enableForTesting({
    required String key,
    required http.Client client,
    String distinctId = 'test-id',
  }) {
    _keyForTesting = key;
    _client = client;
    _distinctId = distinctId;
    _enabled = true;
  }

  @visibleForTesting
  static void resetForTesting() {
    _keyForTesting = '';
    _client = null;
    _distinctId = null;
    _enabled = false;
  }
}

/// Reports a `screen_view` event whenever the app pushes, replaces or pops
/// back to a screen. Registered in `MaterialApp.navigatorObservers`.
///
/// The app's routes are anonymous `MaterialPageRoute`s, so the screen name is
/// found by looking for the first widget under the route whose class name ends
/// in `Screen` or `Shell`. On release **web** builds Dart class names are
/// minified, so those names are replaced with `unknown` rather than sending
/// junk; giving routes a `RouteSettings(name: ...)` fixes that everywhere.
class TelemetryNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _report(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _report(previousRoute);
  }

  void _report(Route<dynamic> route) {
    if (!Telemetry.isEnabled) return;
    // Wait a frame so the route's widgets exist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final name = screenNameFor(route);
        if (name != null) Telemetry.track('screen_view', {'screen': name});
      } catch (_) {}
    });
  }

  /// Visible for tests.
  @visibleForTesting
  static String? screenNameFor(Route<dynamic> route) {
    if (route is PopupRoute) return null; // dialogs, bottom sheets, menus
    final named = route.settings.name;
    if (named != null && named.isNotEmpty && named != '/') return named;

    if (route is ModalRoute) {
      final ctx = route.subtreeContext;
      if (ctx != null) {
        String? found;
        void visit(Element e, int depth) {
          if (found != null || depth > 14) return;
          final type = e.widget.runtimeType.toString();
          if (RegExp(r'^[A-Z][A-Za-z0-9]{3,}(Screen|Shell)$').hasMatch(type)) {
            found = type;
            return;
          }
          e.visitChildren((c) => visit(c, depth + 1));
        }

        (ctx as Element).visitChildren((c) => visit(c, 0));
        return found ?? 'unknown';
      }
    }
    return 'unknown';
  }
}
