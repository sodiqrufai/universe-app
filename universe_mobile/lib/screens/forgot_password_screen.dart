import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_email_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await AuthEmailService.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _sent = true;
      } else {
        _error = r.error;
      }
    });
    if (r.ok) _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent ? _buildSent() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text('Forgot your password?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Enter your email and we\'ll send you a link to choose a new password.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _submit(),
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!, style: TextStyle(color: AppColors.error)),
          ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Send Reset Link'),
        ),
      ],
    );
  }

  Widget _buildSent() {
    final email = _emailController.text.trim();
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 64),
        const SizedBox(height: 24),
        const Text('Check your email',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'If an account exists for $email, we\'ve sent a link to reset your password. '
          'Open it on any device, choose a new password, then come back here to log in.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'Nothing there? Check your spam folder.',
          style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Log In'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: (_cooldown > 0 || _loading) ? null : _submit,
          child: Text(_cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email'),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: AppColors.error)),
      ],
    );
  }
}
