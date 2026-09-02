import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/sign_up_data.dart';
import '../models/profile_setup_data.dart';
import '../services/session_service.dart';
import 'profile_photo_screen.dart';
import 'login_screen.dart';

/// Step 5 of 12: Confirm Password.
///
/// This is where the account actually gets created — /auth/register
/// needs email + password together, so nothing before this step could
/// hit the backend. /auth/register now accepts fullName directly, so
/// that's saved in the same call. Username is NOT saved here — it's
/// carried forward as pending local state and only saved together with
/// level via PATCH /profile/complete-setup at the end of the flow,
/// matching the backend's own abandon-safety design.
class ConfirmPasswordScreen extends StatefulWidget {
  final SignUpData data;
  const ConfirmPasswordScreen({super.key, required this.data});

  @override
  State<ConfirmPasswordScreen> createState() => _ConfirmPasswordScreenState();
}

class _ConfirmPasswordScreenState extends State<ConfirmPasswordScreen> {
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _needsConfirmation = false;
  String? _error;

  Future<void> _continue() async {
    if (_confirmController.text != widget.data.password) {
      setState(() => _error = 'Passwords don\'t match');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      // Raw http, not ApiService — this call happens before any account
      // (and therefore any token) exists.
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.data.email,
          'password': widget.data.password,
          'fullName': widget.data.fullName,
        }),
      );
      final registerData = jsonDecode(response.body);

      if (registerData['success'] != true) {
        setState(() {
          _error = registerData['error'] ?? 'Registration failed';
          _submitting = false;
        });
        return;
      }

      // Backend can now return success:true with no session at all when
      // email confirmation is pending — accessToken/refreshToken won't
      // exist in that response, so there's nothing to save yet and
      // nowhere authenticated to navigate to.
      if (registerData['needsConfirmation'] == true || registerData['accessToken'] == null) {
        setState(() {
          _needsConfirmation = true;
          _submitting = false;
        });
        return;
      }

      await SessionService.save(
        registerData['accessToken'],
        registerData['userId'],
        refreshToken: registerData['refreshToken'],
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfilePhotoScreen(
            setupData: ProfileSetupData(username: widget.data.username),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Could not connect — check your connection and try again';
        _submitting = false;
      });
    }
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsConfirmation) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, color: AppColors.primary, size: 56),
              const SizedBox(height: 24),
              const Text(
                'Confirm your email',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a confirmation link to ${widget.data.email}. Verify it, then log in to finish setting up your profile.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                ),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepProgressDots(currentStep: 5, totalSteps: 12),
            const SizedBox(height: 24),
            const Text(
              'Confirm your password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _confirmController,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _continue(),
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            ElevatedButton(
              onPressed: _submitting ? null : _continue,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
