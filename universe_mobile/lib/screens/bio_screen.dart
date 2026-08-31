import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../services/api_service.dart';
import 'university_selector_screen.dart';

/// Step 7 of 12: Bio (optional, 150 char cap).
class BioScreen extends StatefulWidget {
  const BioScreen({super.key});

  @override
  State<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends State<BioScreen> {
  final _bioController = TextEditingController();
  bool _saving = false;
  String? _error;

  static const _maxLength = 150;

  Future<void> _continue() async {
    final bio = _bioController.text.trim();
    if (bio.isEmpty) {
      _goNext();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await ApiService.patch('/profile/update', {'bio': bio});
      if (data['success'] == true) {
        _goNext();
      } else if (mounted) {
        setState(() {
          _error = data['error'] ?? 'Could not save bio';
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save bio — check your connection';
          _saving = false;
        });
      }
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UniversitySelectorScreen()),
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            ElevatedButton(
              onPressed: _saving ? null : _continue,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_bioController.text.trim().isEmpty ? 'Skip for now' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
