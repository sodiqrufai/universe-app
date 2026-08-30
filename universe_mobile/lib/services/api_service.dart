import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_service.dart';
import '../config/api_config.dart';

class ApiService {
  static const _baseUrl = ApiConfig.baseUrl;

  /// Parses a response body and normalizes it to this app's usual
  /// {success, error} shape. NestJS's default exception responses
  /// (403 restricted/suspended, validation errors, etc.) come back as
  /// {statusCode, message, error: "Forbidden"} instead — that "error"
  /// field is just the exception *type* name, not a usable message, so
  /// screens reading data['error'] would show "Forbidden" instead of
  /// "Your account has been suspended." This backfills 'error' from
  /// 'message' whenever the response isn't already in the app's shape.
  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return {'success': false, 'error': 'Unexpected response from server'};
    }
    if (decoded['success'] != true && decoded['error'] == null && decoded['message'] != null) {
      final message = decoded['message'];
      decoded['error'] = message is List ? message.join(', ') : message.toString();
    }
    // A 403 from assertNotRestricted() means the account is suspended
    // or temporarily restricted — flag it so calling screens can show
    // a dedicated dialog instead of a snackbar that's easy to miss.
    if (response.statusCode == 403 && decoded['error'] != null) {
      decoded['restricted'] = true;
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final token = await SessionService.getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = await SessionService.getToken();
        final retry = await http.get(
          Uri.parse('$_baseUrl$path'),
          headers: {'Authorization': 'Bearer $newToken'},
        );
        return _decode(retry);
      }
    }
    return _decode(response);
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await SessionService.getToken();
    final response = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = await SessionService.getToken();
        final retry = await http.patch(
          Uri.parse('$_baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $newToken',
          },
          body: jsonEncode(body),
        );
        return _decode(retry);
      }
    }
    return _decode(response);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await SessionService.getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = await SessionService.getToken();
        final retry = await http.post(
          Uri.parse('$_baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $newToken',
          },
          body: jsonEncode(body),
        );
        return _decode(retry);
      }
    }
    return _decode(response);
  }

  static Future<bool> _tryRefresh() async {
    final refreshToken = await SessionService.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final userId = await SessionService.getUserId();
        await SessionService.save(
          data['accessToken'],
          userId!,
          refreshToken: data['refreshToken'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final token = await SessionService.getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = await SessionService.getToken();
        final retry = await http.delete(
          Uri.parse('$_baseUrl$path'),
          headers: {'Authorization': 'Bearer $newToken'},
        );
        return _decode(retry);
      }
    }
    return _decode(response);
  }
}
