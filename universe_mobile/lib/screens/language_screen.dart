import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Only English is actually supported right now — the app has no
/// localization/i18n setup, no translated strings, nothing. This screen
/// is honest about that rather than showing a picker with languages
/// that don't do anything when selected.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.lightPurple, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text('English', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'More languages aren\'t available yet — UniVerse currently only supports English.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
