import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'session_service.dart';
import '../config/api_config.dart';

class ApiService {
  static const _baseUrl = ApiConfig.baseUrl;

  static const _networkErrorMessage =
      'Could not reach the server. Check your connection and try again — '
      'the server may also be waking up, which can take up to a minute.';

  /// Safely decodes a response body. If the body isn't valid JSON (e.g. a
  /// gateway/HTML error page during a Render cold start), returns a
  /// consistent failure map instead of throwing.
  static Map<String, dynamic> _safeDecode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {
        'success': false,
        'error': 'Unexpected response from server (status ${response.statusCode}).',
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'Unexpected response from server (status ${response.statusCode}).',
      };
    }
  }

  /// Wraps any network-level failure (timeout, DNS failure, connection
  /// refused, etc.) so callers always get a Map back instead of a thrown
  /// exception.
  static Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on SocketException {
      return {'success': false, 'error': _networkErrorMessage};
    } on HttpException {
      return {'success': false, 'error': _networkErrorMessage};
    } on FormatException {
      return {'success': false, 'error': _networkErrorMessage};
    } catch (e) {
      return {'success': false, 'error': _networkErrorMessage};
    }
  }

  static Future<Map<String, dynamic>> get(String path) {
    return _guard(() async {
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
          return _safeDecode(retry);
        }
      }
      return _safeDecode(response);
    });
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) {
    return _guard(() async {
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
          return _safeDecode(retry);
        }
      }
      return _safeDecode(response);
    });
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) {
    return _guard(() async {
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
          return _safeDecode(retry);
        }
      }
      return _safeDecode(response);
    });
  }

  static Future<Map<String, dynamic>> delete(String path) {
    return _guard(() async {
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
          return _safeDecode(retry);
        }
      }
      return _safeDecode(response);
    });
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
}