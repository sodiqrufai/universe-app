import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
// import '../services/session_service.dart';

/// There's no in-app "enter old + new password" endpoint on this
/// backend — the only thing that exists is /auth/reset-password, which
/// sends a reset link by email. Rather than build a form with nothing
/// real to submit to, this screen is honest about what actually
/// happens: it sends you that email, using the address on your account.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _sending = false;
  bool _sent = false;
  String? _error;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    try {
      final data = await ApiService.get('/profile/me');
      if (data['success'] == true && mounted) {
        setState(() => _email = data['profile']?['email']);
      }
    } catch (_) {}
  }

  Future<void> _sendResetEmail() async {
    if (_email == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // final token = await SessionService.getToken();
      // /auth/reset-password takes only {email} and needs no auth
      // token itself, but we still route it through the same base
      // config as everywhere else for consistency.
      final data = await ApiService.post('/auth/reset-password', {'email': _email});
      if (mounted) {
        if (data['success'] == true) {
          setState(() => _sent = true);
        } else {
          setState(() => _error = data['error'] ?? 'Could not send reset email');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send reset email');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 40),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'To change your password, we\'ll email you a secure reset link.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_email != null)
              Text(
                'We\'ll send it to $_email',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            const SizedBox(height: AppSpacing.xxl),
            if (_sent)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Reset email sent — check your inbox.',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: (_sending || _email == null) ? null : _sendResetEmail,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Reset Email'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
          ],
        ),
      ),
    );
  }
}
