import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/sign_up_data.dart';
import '../services/api_service.dart';
import 'create_password_screen.dart';
import 'profile_photo_screen.dart';

/// Step 3 of 12: Username.
///
/// Honest note on "live availability check": there's no backend
/// endpoint to check username uniqueness before an account exists (and
/// no account exists yet at this step — /auth/register needs email+
/// password together, which come later). What this screen actually
/// does live is format validation (length, allowed characters). Real
/// uniqueness is only checked once the account is created, at step 5 —
/// if it turns out taken, [retryAfterRegistration] routes back here
/// directly to fix it and retry, without re-asking for the password.
class UsernameScreen extends StatefulWidget {
  final SignUpData data;
  final bool retryAfterRegistration;

  const UsernameScreen({
    super.key,
    required this.data,
    this.retryAfterRegistration = false,
  });

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  late final _usernameController = TextEditingController(text: widget.data.username);
  String? _error;
  bool _submitting = false;

  static final _usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');

  String? _formatError(String username) {
    if (username.isEmpty) return 'Choose a username';
    if (!_usernameRegex.hasMatch(username)) {
      return '3-20 characters: lowercase letters, numbers, underscores only';
    }
    return null;
  }

  Future<void> _continue() async {
    final username = _usernameController.text.trim().toLowerCase();
    final formatError = _formatError(username);
    if (formatError != null) {
      setState(() => _error = formatError);
      return;
    }
    setState(() => _error = null);

    if (widget.retryAfterRegistration) {
      setState(() => _submitting = true);
      try {
        final data = await ApiService.patch('/profile/update', {'username': username});
        if (data['success'] == true) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()),
            );
          }
        } else if (mounted) {
          setState(() => _error = _friendlyUsernameError(data['error']));
        }
      } catch (_) {
        if (mounted) setState(() => _error = 'Could not save username — try again');
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePasswordScreen(data: widget.data.copyWith(username: username)),
      ),
    );
  }

  String _friendlyUsernameError(String? raw) {
    final lower = (raw ?? '').toLowerCase();
    if (lower.contains('duplicate') || lower.contains('unique') || lower.contains('already')) {
      return 'That username is already taken — try another.';
    }
    return raw ?? 'Could not save username';
  }

  @override
  void dispose() {
    _usernameController.dispose();
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
            const StepProgressDots(currentStep: 3, totalSteps: 12),
            const SizedBox(height: 24),
            const Text(
              'Choose a username',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is your unique @handle on UniVerse.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (v) => setState(() => _error = null),
              onSubmitted: (_) => _continue(),
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                prefixIcon: Icon(Icons.alternate_email),
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
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
