import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'login_screen.dart';

/// Distinct from WaitlistScreen (the join screen). This is what a
/// user sees on every subsequent app launch once they've already
/// joined the waitlist — resumed here by splash_screen.dart, not a
/// step in the onboarding chain. There's nothing to do here but wait
/// or sign out; the app deliberately can't be gotten past this by
/// design, not stuck due to a bug.
class WaitlistHoldingScreen extends StatelessWidget {
  final String universityName;
  const WaitlistHoldingScreen({super.key, required this.universityName});

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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'You\'re on the list',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ll email you the moment UniVerse launches at $universityName. No need to keep checking back.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => _logout(context),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
