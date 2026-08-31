import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/step_progress_dots.dart';
import 'review_screen.dart';

/// Step 11 of 12: Level. Split out of department_selector_screen.dart
/// so it gets its own dot instead of being a hidden second phase.
class LevelSelectorScreen extends StatefulWidget {
  const LevelSelectorScreen({super.key});

  @override
  State<LevelSelectorScreen> createState() => _LevelSelectorScreenState();
}

class _LevelSelectorScreenState extends State<LevelSelectorScreen> {
  final List<String> _levels = ['100L', '200L', '300L', '400L', '500L'];
  String? _error;
  bool _submitting = false;

  Future<void> _selectLevel(String level) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = await ApiService.patch('/profile/update', {'level': level});
      if (data['success'] == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReviewScreen()),
        );
      } else if (mounted) {
        setState(() {
          _error = data['error'] ?? 'Failed to save your level';
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save your level';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Level')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: StepProgressDots(currentStep: 11, totalSteps: 12),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _levels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final level = _levels[index];
                return Card(
                  child: ListTile(
                    enabled: !_submitting,
                    leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                    title: Text(level),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectLevel(level),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
