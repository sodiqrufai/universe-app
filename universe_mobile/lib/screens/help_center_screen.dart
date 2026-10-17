import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/support_config.dart';
import '../theme/app_theme.dart';
import 'feedback_screen.dart';

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

  Future<void> _open(BuildContext context, Uri uri, String fallbackText) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      await Clipboard.setData(ClipboardData(text: fallbackText));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t open an app. Copied $fallbackText instead.')),
      );
    }
  }

  Widget _contactRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: onTap,
      ),
    );
  }

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
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Still need help?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _contactRow(
            context,
            icon: Icons.mail_outline,
            title: 'Email support',
            subtitle: SupportConfig.email,
            onTap: () => _open(
              context,
              SupportConfig.emailUri(subject: 'UniVerse support'),
              SupportConfig.email,
            ),
          ),
          if (SupportConfig.hasWhatsapp)
            _contactRow(
              context,
              icon: Icons.chat_outlined,
              title: 'Chat on WhatsApp',
              subtitle: 'Message us directly',
              onTap: () => _open(
                context,
                SupportConfig.whatsappUri(),
                '+${SupportConfig.whatsapp}',
              ),
            ),
          _contactRow(
            context,
            icon: Icons.feedback_outlined,
            title: 'Send feedback',
            subtitle: 'Report a bug or share an idea',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
