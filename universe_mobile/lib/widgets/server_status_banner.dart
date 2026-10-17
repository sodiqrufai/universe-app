import 'package:flutter/material.dart';

import '../services/server_status.dart';

/// Wraps the whole app (from `MaterialApp.builder`) and shows a slim banner at
/// the top when the server is slow to answer or the device is offline.
///
/// The banner pushes the app down instead of covering it, and removes the
/// status-bar padding from the app underneath while it is showing, so
/// AppBars don't end up with a double gap.
class ServerStatusHost extends StatelessWidget {
  const ServerStatusHost({super.key, required this.child, this.status});

  final Widget child;

  /// Defaults to [ServerStatus.instance]; overridable in tests.
  final ServerStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status ?? ServerStatus.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        // Offline wins over "waking up": no point waiting for a server we
        // can't reach.
        final String? message = s.isOffline
            ? "You're offline. We'll reconnect when your internet is back."
            : s.isWaking
                ? 'Waking up the server, this can take up to a minute...'
                : null;
        final bool offline = s.isOffline;

        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: message == null
                  ? const SizedBox(width: double.infinity)
                  : _Banner(message: message, offline: offline),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: message != null,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.offline});

  final String message;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Semantics(
      liveRegion: true,
      child: Material(
        // Fixed colors (not theme getters) so white text stays readable in
        // both light and dark mode.
        color: offline ? const Color(0xFF3A3A4A) : const Color(0xFF2D1B8C),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 8),
          child: Row(
            children: [
              if (offline)
                const Icon(Icons.wifi_off, size: 16, color: Colors.white)
              else
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
