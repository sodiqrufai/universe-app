import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide "how is the connection to our server?" state.
///
/// * [isWaking]  - at least one API request has been waiting longer than the
///   "slow" threshold (Render's free tier sleeps and can take up to a minute
///   to wake). The banner then says "Waking up the server...".
/// * [isOffline] - the device reports no network (connectivity_plus), and no
///   API request has succeeded since.
///
/// Written to by [ResilientClient] and the connectivity monitor; read by
/// `ServerStatusBanner`.
class ServerStatus extends ChangeNotifier {
  ServerStatus();

  /// The instance the app uses. Tests create their own with `ServerStatus()`.
  static final ServerStatus instance = ServerStatus();

  final Set<int> _slowRequests = <int>{};
  int _nextId = 0;
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get isWaking => _slowRequests.isNotEmpty;
  bool get isOffline => _offline;

  /// Called when a request has been in flight longer than the slow threshold.
  /// Returns an id to pass to [requestFinished].
  int requestSlow() {
    final id = _nextId++;
    _slowRequests.add(id);
    notifyListeners();
    return id;
  }

  void requestFinished(int id) {
    if (_slowRequests.remove(id)) notifyListeners();
  }

  void setOffline(bool value) {
    if (_offline == value) return;
    _offline = value;
    notifyListeners();
  }

  /// A response (any status) arrived from our server, so we are online no
  /// matter what the OS-level connectivity flag says.
  void markReachable() => setOffline(false);

  /// Starts listening to OS connectivity changes. Safe to call more than once
  /// and safe if the plugin is unavailable (it just never reports offline).
  Future<void> startConnectivityMonitoring([Connectivity? connectivity]) async {
    if (_connectivitySub != null) return;
    try {
      final c = connectivity ?? Connectivity();
      setOffline(_isNone(await c.checkConnectivity()));
      _connectivitySub = c.onConnectivityChanged.listen(
        (results) => setOffline(_isNone(results)),
        onError: (_) {},
      );
    } catch (_) {
      // Plugin missing / unsupported platform: stay "online".
    }
  }

  static bool _isNone(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
