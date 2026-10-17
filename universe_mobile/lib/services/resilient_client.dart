import 'dart:async';

import 'package:http/http.dart' as http;

import 'server_status.dart';

/// Thrown by [ResilientClient] when a request fails at the network level.
/// It extends [http.ClientException] so existing `catch` blocks keep working,
/// and its `toString()` is just the friendly message, so screens that do
/// `'Error: $e'` show something a student can understand.
class ResilientHttpException extends http.ClientException {
  ResilientHttpException(
    super.message,
    super.uri, {
    this.timedOut = false,
    this.offline = false,
  });

  /// The request ran out of time (no response within the timeout).
  final bool timedOut;

  /// The device appeared to be offline when the request failed.
  final bool offline;

  @override
  String toString() => message;
}

/// An [http.Client] installed app-wide (see main.dart, `http.runWithClient`)
/// so every `http.get/post/...` and every `MultipartRequest.send()` in the app
/// gets, without editing any screen:
///
///  * a timeout (25 s normally, 5 min for uploads),
///  * automatic retries for idempotent requests (GET/HEAD/OPTIONS) on network
///    failures, timeouts and 502/503/504 (Render waking up),
///  * a friendly [ResilientHttpException] when it finally gives up,
///  * "server is slow" reporting to [ServerStatus] after ~6 s.
///
/// Only requests to [apiHost] get this treatment; images, fonts and anything
/// else pass straight through to the inner client.
///
/// POST/PATCH/DELETE and multipart uploads are never retried automatically:
/// a failed response doesn't prove the server didn't act on it, and a retry
/// could post twice.
class ResilientClient extends http.BaseClient {
  ResilientClient({
    required http.Client inner,
    required this.apiHost,
    ServerStatus? status,
    this.timeout = const Duration(seconds: 25),
    this.uploadTimeout = const Duration(minutes: 5),
    this.slowAfter = const Duration(seconds: 6),
    this.retries = 2,
    this.backoff = const [Duration(milliseconds: 800), Duration(seconds: 2)],
    bool Function()? isOffline,
    Future<void> Function(Duration)? sleep,
  })  // ignore: prefer_initializing_formals
      : _inner = inner,
        _status = status ?? ServerStatus.instance,
        // ignore: prefer_initializing_formals
        _isOffline = isOffline,
        _sleep = sleep ?? ((Duration d) => Future<void>.delayed(d));

  final http.Client _inner;
  final ServerStatus _status;
  final bool Function()? _isOffline;
  final Future<void> Function(Duration) _sleep;

  /// Host of the backend, e.g. `universe-app-w4cc.onrender.com`.
  final String apiHost;

  /// Max wait for a response to a normal request.
  final Duration timeout;

  /// Max wait for a multipart/streamed (upload) request.
  final Duration uploadTimeout;

  /// How long a request may run before the "waking up" banner appears.
  final Duration slowAfter;

  /// Extra attempts for retryable requests (so up to `retries + 1` tries).
  final int retries;

  /// Wait before retry 1, retry 2, ... (the last value repeats).
  final List<Duration> backoff;

  static const Set<int> _retryStatuses = {502, 503, 504};
  static const Set<String> _idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  bool _isApiRequest(Uri url) => url.host == apiHost;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isApiRequest(request.url)) return _inner.send(request);

    final isUpload = request is! http.Request;
    final limit = isUpload ? uploadTimeout : timeout;
    final offlineAtStart = _isOffline?.call() ?? false;
    final canRetry = request is http.Request &&
        _idempotentMethods.contains(request.method.toUpperCase()) &&
        !offlineAtStart;

    int? slowId;
    final slowTimer = Timer(slowAfter, () => slowId = _status.requestSlow());
    try {
      var attempt = 0;
      while (true) {
        // The first attempt uses the caller's request; retries need a fresh
        // copy because a request can only be sent once.
        final toSend = attempt == 0 ? request : _copy(request as http.Request);
        try {
          final response = await _inner.send(toSend).timeout(limit);
          if (canRetry &&
              _retryStatuses.contains(response.statusCode) &&
              attempt < retries) {
            await _discard(response);
            attempt++;
            await _sleep(_delayFor(attempt));
            continue;
          }
          // Any response means the server is reachable.
          _status.markReachable();
          return response;
        } on TimeoutException {
          if (canRetry && attempt < retries) {
            attempt++;
            await _sleep(_delayFor(attempt));
            continue;
          }
          throw ResilientHttpException(
            'The server is taking too long to respond. It may be waking up, '
            'so please try again in a moment.',
            request.url,
            timedOut: true,
          );
        } catch (e) {
          // Programming mistakes (Error) must surface, not be disguised as
          // "no internet". Network failures are Exceptions.
          if (e is Error) rethrow;
          if (e is ResilientHttpException) rethrow;
          if (canRetry && attempt < retries) {
            attempt++;
            await _sleep(_delayFor(attempt));
            continue;
          }
          final offline = (_isOffline?.call() ?? false);
          throw ResilientHttpException(
            offline
                ? "You're offline. Check your internet connection and try again."
                : "Couldn't reach the server. Check your connection and try "
                    'again; the server may also be waking up.',
            request.url,
            offline: offline,
          );
        }
      }
    } finally {
      slowTimer.cancel();
      final id = slowId;
      if (id != null) _status.requestFinished(id);
    }
  }

  Duration _delayFor(int attempt) {
    if (backoff.isEmpty) return Duration.zero;
    final i = attempt - 1;
    return backoff[i < backoff.length ? i : backoff.length - 1];
  }

  /// Drains and drops a response we are about to retry past, so its
  /// connection is released. Errors while draining don't matter.
  Future<void> _discard(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  http.Request _copy(http.Request original) {
    return http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..bodyBytes = original.bodyBytes;
  }

  /// `http.get(...)` and `MultipartRequest.send()` create a client per call
  /// and close it afterwards. The inner client is shared by the whole app, so
  /// closing a [ResilientClient] must NOT close it.
  @override
  void close() {}
}
