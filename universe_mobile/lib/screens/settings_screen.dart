import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'my_posts_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'anonymous_username_screen.dart';
import 'blocked_users_screen.dart';
import 'delete_account_screen.dart';
import 'saved_listings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await SessionService.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _section('Content'),
          _tile(context, Icons.article_outlined, 'My Posts', () => const MyPostsScreen()),
          _tile(context, Icons.bookmark_border, 'Saved Items', () => const SavedListingsScreen()),
          _section('Privacy & Safety'),
          _tile(context, Icons.privacy_tip_outlined, 'Privacy', () => const PrivacySettingsScreen()),
          _tile(context, Icons.notifications_outlined, 'Notifications', () => const NotificationSettingsScreen()),
          _tile(context, Icons.masks_outlined, 'Anonymous Identity', () => const AnonymousUsernameScreen()),
          _tile(context, Icons.block, 'Blocked Users', () => const BlockedUsersScreen()),
          _section('Account'),
          _tile(context, Icons.delete_outline, 'Delete Account', () => const DeleteAccountScreen(), isDanger: true),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.primary),
            title: const Text('Log Out'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13)),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, Widget Function() screenBuilder, {bool isDanger = false}) {
    return ListTile(
      leading: Icon(icon, color: isDanger ? Colors.red : AppColors.primary),
      title: Text(label, style: TextStyle(color: isDanger ? Colors.red : null)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenBuilder()));
      },
    );
  }
}