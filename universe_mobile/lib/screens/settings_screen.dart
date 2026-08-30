import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'verification_screen.dart';
import 'my_posts_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'anonymous_username_screen.dart';
import 'blocked_users_screen.dart';
import 'delete_account_screen.dart';
import 'saved_listings_screen.dart';
import 'change_password_screen.dart';
import 'language_screen.dart';
import 'help_center_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // null = still checking, true/false = known status
  bool? _isVerified;

  @override
  void initState() {
    super.initState();
    _fetchVerificationStatus();
  }

  Future<void> _fetchVerificationStatus() async {
    try {
      final data = await ApiService.get('/profile/me');
      if (mounted && data['success'] == true) {
        setState(() {
          _isVerified = data['profile']?['is_verified'] == true;
        });
      }
    } catch (_) {
      // Settings page still works without the badge — fail quietly here.
    }
  }

  Future<void> _logout(BuildContext context) async {
    await SessionService.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _sectionLabel('Account'),
          _sectionCard([
            _tile(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              subtitle: 'Update your personal information',
              onTap: () => _push(const EditProfileScreen()),
            ),
            _tile(
              icon: Icons.verified_user_outlined,
              label: 'Account Verification',
              subtitle: 'View verification status',
              trailing: _verificationBadge(),
              onTap: () => _push(const VerificationScreen()),
            ),
            _tile(
              icon: Icons.lock_outline,
              label: 'Change Password',
              subtitle: 'Send a password reset email',
              onTap: () => _push(const ChangePasswordScreen()),
            ),
          ]),
          _sectionLabel('Preferences'),
          _sectionCard([
            _tile(
              icon: Icons.language_outlined,
              label: 'Language',
              subtitle: 'English',
              onTap: () => _push(const LanguageScreen()),
            ),
            _tile(
              icon: Icons.dark_mode_outlined,
              label: 'Dark Mode',
              subtitle: 'Coming soon',
              onTap: null,
            ),
          ]),
          _sectionLabel('Content'),
          _sectionCard([
            _tile(
              icon: Icons.article_outlined,
              label: 'My Posts',
              subtitle: 'Posts you\'ve shared',
              onTap: () => _push(const MyPostsScreen()),
            ),
            _tile(
              icon: Icons.bookmark_border,
              label: 'Saved Items',
              subtitle: 'View and manage your saved posts and items',
              onTap: () => _push(const SavedListingsScreen()),
            ),
          ]),
          _sectionLabel('Privacy & Safety'),
          _sectionCard([
            _tile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy',
              subtitle: 'Manage your privacy settings',
              onTap: () => _push(const PrivacySettingsScreen()),
            ),
            _tile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              subtitle: 'Manage push notifications',
              onTap: () => _push(const NotificationSettingsScreen()),
            ),
            _tile(
              icon: Icons.masks_outlined,
              label: 'Anonymous Identity',
              subtitle: 'Change your anonymous username',
              onTap: () => _push(const AnonymousUsernameScreen()),
            ),
            _tile(
              icon: Icons.block,
              label: 'Blocked Users',
              subtitle: 'Manage people you\'ve blocked',
              onTap: () => _push(const BlockedUsersScreen()),
            ),
          ]),
          _sectionLabel('Support & About'),
          _sectionCard([
            _tile(
              icon: Icons.help_outline,
              label: 'Help Center',
              subtitle: 'Get help and answers',
              onTap: () => _push(const HelpCenterScreen()),
            ),
            _tile(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              subtitle: 'Read our terms',
              onTap: () => _push(const TermsScreen()),
            ),
            _tile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () => _push(const PrivacyPolicyScreen()),
            ),
            _tile(
              icon: Icons.info_outline,
              label: 'About UniVerse',
              subtitle: 'Version 1.0.0',
              onTap: null,
            ),
          ]),
          _sectionLabel('Danger Zone'),
          _sectionCard([
            _tile(
              icon: Icons.delete_outline,
              label: 'Delete Account',
              subtitle: 'Permanently remove your account and data',
              isDanger: true,
              onTap: () => _push(const DeleteAccountScreen()),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Your security is important to us. We\'ll never share your data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _verificationBadge() {
    if (_isVerified == null) return null;
    if (_isVerified == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Verified',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Pending',
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i != tiles.length - 1)
              const Divider(height: 1, indent: 56, color: Color(0xFFF0F0F5)),
          ],
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    bool isDanger = false,
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isDanger
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.1),
        child: Icon(
          icon,
          size: 18,
          color: isDanger ? AppColors.error : AppColors.primary,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDanger ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                trailing,
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ],
            )
          : (onTap != null
              ? const Icon(Icons.chevron_right, color: AppColors.textMuted)
              : null),
      onTap: onTap,
    );
  }
}
