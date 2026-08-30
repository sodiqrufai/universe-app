import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _faqs = [
    (
      'How do I get verified as a student?',
      'Go to Settings > Account Verification, or tap the verification banner on your Profile. Upload a clear photo of your student ID and we\'ll review it within 24-48 hours.',
    ),
    (
      'Is Anonymous really anonymous?',
      'Yes — your anonymous posts use a separate identity that isn\'t linked to your profile in the app. Only in exceptional safety cases can a super admin reveal an identity, and that action is always logged.',
    ),
    (
      'How do I report something?',
      'Tap the flag icon or the "..." menu on any post, listing, service, event, or chat, and choose Report.',
    ),
    (
      'Why was my content removed?',
      'If a moderator removes something you posted, you\'ll see it clearly marked in "My Posts" along with the reason. You\'ll also get a notification.',
    ),
    (
      'How do I delete my account?',
      'Settings > Account Verification section > scroll to the bottom for Delete Account. This is permanent and cannot be undone.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final faq in _faqs)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.$1,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    faq.$2,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Row(
              children: [
                Icon(Icons.mail_outline, color: AppColors.primary),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Still need help? Reach us at support@universe.app',
                    style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
