import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/step_progress_dots.dart';
import '../models/profile_setup_data.dart';
import 'university_selector_screen.dart';

/// Step 7 of 12: Bio (optional, 150 char cap). Not saved yet during
/// sign-up — held as pending state and only written together with
/// username + level via PATCH /profile/complete-setup at the end of
/// the flow. Also reused as an edit entry point from ReviewScreen
/// (editMode: true) — there the account is already fully set up, so
/// this saves immediately via PATCH /profile/update and pops back
/// instead of continuing to UniversitySelectorScreen.
class BioScreen extends StatefulWidget {
  final ProfileSetupData setupData;
  final bool editMode;
  const BioScreen({super.key, required this.setupData, this.editMode = false});

  @override
  State<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends State<BioScreen> {
  late final _bioController = TextEditingController(text: widget.setupData.bio);
  bool _saving = false;

  static const _maxLength = 150;

  Future<void> _continue() async {
    final bio = _bioController.text.trim();

    if (!widget.editMode) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UniversitySelectorScreen(
            setupData: widget.setupData.copyWith(bio: bio),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final data = await ApiService.patch('/profile/update', {'bio': bio});
    if (!mounted) return;
    if (data['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Could not save your bio')));
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editMode ? 'Edit Bio' : 'Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.editMode) ...[
              const StepProgressDots(currentStep: 7, totalSteps: 12),
              const SizedBox(height: 24),
            ],
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
              onPressed: _saving ? null : _continue,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.editMode
                          ? 'Save'
                          : (_bioController.text.trim().isEmpty ? 'Skip for now' : 'Continue'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
