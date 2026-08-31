import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/sign_up_data.dart';
import 'username_screen.dart';

/// Step 2 of 12: Name. Still purely local state.
class NameScreen extends StatefulWidget {
  final SignUpData data;
  const NameScreen({super.key, required this.data});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final _nameController = TextEditingController(text: widget.data.fullName);
  String? _error;

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isEmpty || !name.contains(' ')) {
      setState(() => _error = 'Enter your full name');
      return;
    }
    setState(() => _error = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsernameScreen(data: widget.data.copyWith(fullName: name)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
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
            const StepProgressDots(currentStep: 2, totalSteps: 12),
            const SizedBox(height: 24),
            const Text(
              'What\'s your name?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is how other students will see you.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _continue(),
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
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
