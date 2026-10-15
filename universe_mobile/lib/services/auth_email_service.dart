import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Result of an email-sending auth call.
class AuthEmailResult {
  final bool ok;
  final String? error;
  const AuthEmailResult(this.ok, [this.error]);
}

/// Pre-login auth emails (no token exists yet, so this uses raw http
/// like login/register do).
class AuthEmailService {
  static Future<AuthEmailResult> _post(String path, String email) async {
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 60));
      final data = jsonDecode(res.body);
      if (data is Map && data['success'] == true) return const AuthEmailResult(true);
      final msg = data is Map ? (data['error'] ?? data['message']) : null;
      return AuthEmailResult(false, msg?.toString() ?? 'Something went wrong. Try again.');
    } catch (_) {
      return const AuthEmailResult(
        false,
        'Could not reach UniVerse. Check your connection and try again — the server may take up to a minute to wake up.',
      );
    }
  }

  static Future<AuthEmailResult> resendConfirmation(String email) =>
      _post('/auth/resend-confirmation', email);

  static Future<AuthEmailResult> sendPasswordReset(String email) =>
      _post('/auth/reset-password', email);
}
