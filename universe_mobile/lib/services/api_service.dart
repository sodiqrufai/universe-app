import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_service.dart';

class ApiService {
  static const _baseUrl = 'http://localhost:3000';

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
        return jsonDecode(retry.body);
      }
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
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
        return jsonDecode(retry.body);
      }
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
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
        return jsonDecode(retry.body);
      }
    }
    return jsonDecode(response.body);
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