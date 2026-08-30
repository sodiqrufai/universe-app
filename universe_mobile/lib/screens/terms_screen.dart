import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Text(
            'Last updated: [add date before publishing]',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          SizedBox(height: AppSpacing.lg),
          _Section(
            title: '1. Eligibility',
            body:
                'UniVerse is for currently enrolled students at participating Nigerian universities. '
                'You must provide accurate information during verification.',
          ),
          _Section(
            title: '2. Your Content',
            body:
                'You retain ownership of what you post. By posting, you grant UniVerse a license to '
                'display it within the app. You are responsible for content you share.',
          ),
          _Section(
            title: '3. Anonymous Posting',
            body:
                'Anonymous posts are not linked to your public profile within the app. In exceptional '
                'safety cases, a super admin may reveal an identity; this action is logged and audited.',
          ),
          _Section(
            title: '4. Prohibited Conduct',
            body:
                'Harassment, hate speech, impersonation, fraud, and posting illegal content are not '
                'permitted and may result in content removal, suspension, or account termination.',
          ),
          _Section(
            title: '5. Marketplace & Services',
            body:
                'Transactions arranged through UniVerse are between students directly. UniVerse does '
                'not guarantee the quality, safety, or legality of listings or services.',
          ),
          _Section(
            title: '6. Account Suspension',
            body:
                'Accounts that violate these terms may be temporarily restricted or suspended. You '
                'will be notified of the reason when this happens.',
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'This is placeholder legal text and has not been reviewed by a lawyer. Replace with '
            'reviewed terms before this app is used by real students.',
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
