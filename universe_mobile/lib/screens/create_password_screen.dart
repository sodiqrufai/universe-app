import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/sign_up_data.dart';
import 'confirm_password_screen.dart';

/// Step 4 of 12: Create Password. Still local — nothing hits the
/// backend until Confirm Password validates the match.
class CreatePasswordScreen extends StatefulWidget {
  final SignUpData data;
  const CreatePasswordScreen({super.key, required this.data});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _continue() {
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() => _error = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmPasswordScreen(data: widget.data.copyWith(password: password)),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
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
            const StepProgressDots(currentStep: 4, totalSteps: 12),
            const SizedBox(height: 24),
            const Text(
              'Create a password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'At least 6 characters.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _continue(),
              decoration: InputDecoration(
                labelText: 'Password',
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
            ElevatedButton(onPressed: _continue, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}
