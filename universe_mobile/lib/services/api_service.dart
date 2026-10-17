import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'resilient_client.dart';
import 'session_service.dart';

/// Talks to the UniVerse backend and ALWAYS returns a map, never throws.
///
/// Every result has:
///  * `success` (bool)
///  * `error`   (human-readable String) whenever `success` is false
///  * `statusCode` (int) whenever a response arrived from the server
///  * `networkError: true` when no usable response arrived (offline, DNS,
///    connection dropped, server not answering)
///  * `timedOut: true` when the request ran out of time
///  * `rateLimited: true` on HTTP 429
///  * `restricted: true` on HTTP 403 (suspended / restricted account)
///
/// Timeouts, retries of GET requests and the "waking up" banner come from the
/// app-wide `ResilientClient` (installed in main.dart); this class creates its
/// clients with `http.Client()`, which inside that zone IS the resilient one.
class ApiService {
  ApiService._();

  static const _baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> get(String path) =>
      _request('GET', path);

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) =>
      _request('PATCH', path, body: body);

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) =>
      _request('POST', path, body: body);

  static Future<Map<String, dynamic>> delete(String path) =>
      _request('DELETE', path);

  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      var response = await _send(
        method,
        path,
        body,
        await SessionService.getToken(),
      );

      if (response.statusCode == 401 && await _refreshOnce()) {
        response = await _send(
          method,
          path,
          body,
          await SessionService.getToken(),
        );
      }
      return _decode(response);
    } on TimeoutException {
      return _failure(_timeoutMessage, timedOut: true, networkError: true);
    } on ResilientHttpException catch (e) {
      return _failure(
        e.message,
        timedOut: e.timedOut,
        networkError: true,
      );
    } catch (e) {
      // A programming mistake should stay visible in debug/Sentry.
      if (e is Error) rethrow;
      return _failure(_networkMessage, networkError: true);
    }
  }

  static Future<http.Response> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token,
  ) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          return await client.get(uri, headers: headers);
        case 'POST':
          return await client.post(uri, headers: headers, body: encoded);
        case 'PATCH':
          return await client.patch(uri, headers: headers, body: encoded);
        case 'DELETE':
          return await client.delete(uri, headers: headers);
        default:
          throw ArgumentError('Unsupported method $method');
      }
    } finally {
      client.close();
    }
  }

  // --- token refresh -----------------------------------------------------------

  /// Only one refresh runs at a time. Refresh tokens are single-use on many
  /// auth servers, so two screens refreshing in parallel (the splash screen
  /// does) could otherwise invalidate each other.
  static Future<bool>? _refreshing;

  static Future<bool> _refreshOnce() {
    final running = _refreshing;
    if (running != null) return running;
    final started = _tryRefresh().whenComplete(() => _refreshing = null);
    _refreshing = started;
    return started;
  }

  static Future<bool> _tryRefresh() async {
    final refreshToken = await SessionService.getRefreshToken();
    if (refreshToken == null) return false;

    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      final data = jsonDecode(response.body);
      if (data is Map && data['success'] == true) {
        final userId = await SessionService.getUserId();
        if (userId == null) return false;
        await SessionService.save(
          data['accessToken'] as String,
          userId,
          refreshToken: data['refreshToken'] as String?,
        );
        return true;
      }
    } catch (_) {
      // Network problem or bad body: the caller falls back to the original
      // 401 response.
    } finally {
      client.close();
    }
    return false;
  }

  // --- response handling ---------------------------------------------------------

  static const _networkMessage =
      "Couldn't reach the server. Check your connection and try again; the "
      'server may also be waking up.';
  static const _timeoutMessage =
      'The server is taking too long to respond. It may be waking up, so '
      'please try again in a moment.';

  /// Error strings that are just an HTTP status name ("Forbidden") or a
  /// framework exception name, not something to show a student.
  static const _statusNames = {
    'bad request',
    'unauthorized',
    'forbidden',
    'not found',
    'conflict',
    'request timeout',
    'payload too large',
    'unprocessable entity',
    'too many requests',
    'internal server error',
    'bad gateway',
    'service unavailable',
    'gateway timeout',
  };

  static bool _isUsableMessage(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (_statusNames.contains(t)) return false;
    if (t.startsWith('throttlerexception')) return false;
    return true;
  }

  static String _defaultErrorFor(int status) {
    switch (status) {
      case 400:
      case 422:
        return "That didn't look right. Please check what you entered and try again.";
      case 401:
        return 'Please sign in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return "We couldn't find that.";
      case 408:
        return _timeoutMessage;
      case 413:
        return 'That file is too large. Choose a smaller one.';
      case 429:
        return 'Too many attempts. Please wait a minute and try again.';
      case 502:
      case 503:
      case 504:
        return 'The server is waking up or temporarily unavailable. Please try again in a moment.';
    }
    if (status >= 500) {
      return 'Something went wrong on our side. Please try again.';
    }
    if (status < 400) return 'Something went wrong. Please try again.';
    return 'Something went wrong (error $status). Please try again.';
  }

  static Map<String, dynamic> _failure(
    String error, {
    int? statusCode,
    bool networkError = false,
    bool timedOut = false,
    bool rateLimited = false,
  }) {
    return {
      'success': false,
      'error': error,
      if (statusCode != null) 'statusCode': statusCode,
      if (networkError) 'networkError': true,
      if (timedOut) 'timedOut': true,
      if (rateLimited) 'rateLimited': true,
    };
  }

  /// Turns any response into the app's {success, error, ...} shape.
  ///
  /// Handles the friendly errors the backend sends now ({success:false,
  /// error:"..."}), the older NestJS shape ({statusCode, message, error:
  /// "Forbidden"} where `error` is only the status name), non-JSON bodies
  /// (e.g. an HTML 502 page while Render wakes up) and empty bodies.
  static Map<String, dynamic> _decode(http.Response response) {
    final status = response.statusCode;
    final rateLimited = status == 429;

    dynamic decoded;
    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        decoded = null;
      }
    }

    if (decoded is! Map<String, dynamic>) {
      // 2xx with an empty body (e.g. 204) is a success.
      if (status >= 200 && status < 300 && body.isEmpty) {
        return {'success': true, 'statusCode': status};
      }
      return _failure(
        status >= 200 && status < 300
            ? 'Unexpected response from server. Please try again.'
            : _defaultErrorFor(status),
        statusCode: status,
        rateLimited: rateLimited,
      );
    }

    final result = Map<String, dynamic>.from(decoded);
    result['statusCode'] = status;

    final failed = status >= 400 || result['success'] == false;
    if (failed) {
      result['success'] = false;
      result['error'] = _pickError(result, status);
      if (rateLimited) result['rateLimited'] = true;
      // A 403 means the account is suspended or temporarily restricted;
      // flag it so screens can show the dedicated dialog.
      if (status == 403) result['restricted'] = true;
    }
    return result;
  }

  /// Friendly text in order of preference: `error` if it is real text,
  /// otherwise `message` (string or list), otherwise a default for the status.
  static String _pickError(Map<String, dynamic> data, int status) {
    final error = data['error'];
    if (error is String && _isUsableMessage(error)) return error;

    final message = data['message'];
    if (message is List) {
      final joined = message.map((m) => m.toString()).join(', ');
      if (_isUsableMessage(joined)) return joined;
    } else if (message is String && _isUsableMessage(message)) {
      return message;
    }
    return _defaultErrorFor(status);
  }
}
