import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Text(
            'Last updated: [add date before publishing]',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'What we collect',
            body:
                'Your name, university email, matric number, and student ID photo during verification; '
                'content you post; and basic usage data needed to run the app.',
          ),
          _Section(
            title: 'How we store it',
            body:
                'Data is stored with our hosting provider using encryption at rest. This protects your '
                'data from unauthorized access to our servers, but is not end-to-end encryption — '
                'UniVerse staff with appropriate access can, when necessary, view content stored on the '
                'platform (for example, to investigate a safety report).',
          ),
          _Section(
            title: 'Anonymous identity',
            body:
                'Your anonymous username is not shown alongside your real profile anywhere in the app. '
                'It can only be linked back to your account by a super admin, in a logged, audited '
                'action, in exceptional cases such as a credible safety threat.',
          ),
          _Section(
            title: 'Who can see your data',
            body:
                'Other students see what you choose to post publicly. University administrators can '
                'see verification documents for review. UniVerse staff can access data as needed for '
                'moderation, safety, and support.',
          ),
          _Section(
            title: 'Your choices',
            body:
                'You can edit your profile, delete individual posts, block other users, and delete your '
                'account entirely at any time from Settings.',
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'This is placeholder legal text and has not been reviewed by a lawyer. Replace with '
            'reviewed policy text before this app is used by real students.',
            style: TextStyle(fontSize: 12, color: AppColors.error, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
