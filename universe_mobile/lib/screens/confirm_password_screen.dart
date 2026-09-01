import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/sign_up_data.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import 'profile_photo_screen.dart';
import 'username_screen.dart';

/// Step 5 of 12: Confirm Password.
///
/// This is where the account actually gets created — /auth/register
/// needs email + password together, so nothing before this step could
/// hit the backend. On success, immediately saves name + username too,
/// since both are already collected and there's no reason to make the
/// user wait through two more screens for data already in hand.
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
        body: jsonEncode({'email': widget.data.email, 'password': widget.data.password}),
      );
      final registerData = jsonDecode(response.body);

      if (registerData['success'] != true) {
        setState(() {
          _error = registerData['error'] ?? 'Registration failed';
          _submitting = false;
        });
        return;
      }

      await SessionService.save(
        registerData['accessToken'],
        registerData['userId'],
        refreshToken: registerData['refreshToken'],
      );

      // Account exists now — save name + username right away.
      final profileData = await ApiService.patch('/profile/update', {
        'fullName': widget.data.fullName,
        'username': widget.data.username,
      });

      if (!mounted) return;

      if (profileData['success'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()),
        );
      } else {
        // The account was created successfully — only the username save
        // failed (almost certainly because it's taken). Route straight
        // back to fix just that, not re-collect the password.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => UsernameScreen(data: widget.data, retryAfterRegistration: true),
          ),
        );
      }
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
              textInputAction: TextInputAction.done,
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
