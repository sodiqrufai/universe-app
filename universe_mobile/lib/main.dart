import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config/api_config.dart';
import 'screens/splash_screen.dart';
import 'services/app_info.dart';
import 'services/resilient_client.dart';
import 'services/server_status.dart';
import 'services/telemetry.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/server_status_banner.dart';

/// Optional crash reporting. Build with `--dart-define=SENTRY_DSN=...`.
/// Without it Sentry is never initialised (a complete no-op).
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const String _sentryEnv = String.fromEnvironment(
  'SENTRY_ENV',
  defaultValue: 'production',
);

void main() {
  // One plain client for the whole app, created HERE, outside the zone below.
  // (Creating it inside would make `http.Client()` call our own factory again.)
  final plainClient = http.Client();
  final apiHost = Uri.parse(ApiConfig.baseUrl).host;

  // Every `http.get/post/...` and every `MultipartRequest.send()` made while
  // this zone is active gets a ResilientClient: timeouts, retries of GET
  // requests and the "waking up" banner, without editing any screen.
  // Everything below (ensureInitialized, runApp, and all later async work)
  // must run inside this zone, which is why it is all inside `_boot`.
  http.runWithClient(
    () => _boot(plainClient),
    () => ResilientClient(
      inner: plainClient,
      apiHost: apiHost,
      isOffline: () => ServerStatus.instance.isOffline,
    ),
  );
}

Future<void> _boot(http.Client plainClient) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Startup helpers must never stop the app from opening.
  try {
    await ThemeController.instance.load();
  } catch (_) {}
  await AppInfo.init();
  // Analytics uses the plain client so its traffic never triggers retries or
  // the "waking up" banner. No-op unless --dart-define=ANALYTICS_KEY is set.
  await Telemetry.init(client: plainClient);
  unawaited(ServerStatus.instance.startConnectivityMonitoring());

  if (_sentryDsn.isEmpty) {
    runApp(const MyApp());
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = _sentryEnv;
      options.release = 'universe_mobile@${AppInfo.version}';
      options.tracesSampleRate = 0.1;
      // Never attach IP address, cookies, request bodies or user details.
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(const MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Rebuilds the whole app (and every AppColors.x call site along with
    // it) whenever the user changes their theme preference, or -- while
    // in "System" mode -- whenever the OS-level setting changes.
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniVerse',
      theme: AppTheme.current(),
      home: const SplashScreen(),
      navigatorObservers: [
        TelemetryNavigatorObserver(),
        if (_sentryDsn.isNotEmpty) SentryNavigatorObserver(),
      ],
      builder: (context, child) =>
          ServerStatusHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
