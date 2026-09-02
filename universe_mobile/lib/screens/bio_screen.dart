import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/profile_setup_data.dart';
import 'university_selector_screen.dart';

/// Step 7 of 12: Bio (optional, 150 char cap). Not saved yet — held as
/// pending state and only written together with username + level via
/// PATCH /profile/complete-setup at the end of the flow.
class BioScreen extends StatefulWidget {
  final ProfileSetupData setupData;
  const BioScreen({super.key, required this.setupData});

  @override
  State<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends State<BioScreen> {
  late final _bioController = TextEditingController(text: widget.setupData.bio);

  static const _maxLength = 150;

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UniversitySelectorScreen(
          setupData: widget.setupData.copyWith(bio: _bioController.text.trim()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
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
            const StepProgressDots(currentStep: 7, totalSteps: 12),
            const SizedBox(height: 24),
            const Text(
              'Add a short bio',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Optional — tell people a bit about yourself.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: _maxLength,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'e.g. Computer Science, class of 2027'),
            ),
            ElevatedButton(
              onPressed: _continue,
              child: Text(_bioController.text.trim().isEmpty ? 'Skip for now' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
