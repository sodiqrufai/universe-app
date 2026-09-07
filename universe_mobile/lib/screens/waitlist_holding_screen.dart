import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'university_selector_screen.dart';

/// Distinct from WaitlistScreen (the join screen). This is what a
/// user sees on every subsequent app launch once they've already
/// joined the waitlist — resumed here by splash_screen.dart, not a
/// step in the onboarding chain. There's nothing to do here but wait,
/// leave the waitlist, or sign out; the app deliberately can't be
/// gotten past this by design, not stuck due to a bug.
class WaitlistHoldingScreen extends StatefulWidget {
  final String universityName;
  const WaitlistHoldingScreen({super.key, required this.universityName});

  @override
  State<WaitlistHoldingScreen> createState() => _WaitlistHoldingScreenState();
}

class _WaitlistHoldingScreenState extends State<WaitlistHoldingScreen> {
  bool _leaving = false;

  Future<void> _leaveWaitlist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Leave the waitlist?'),
        content: Text(
          'You\'ll need to pick a university again if you change your mind. '
          '${widget.universityName} may still not be available yet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _leaving = true);
    final data = await ApiService.delete('/waitlist/leave');
    if (!mounted) return;
    if (data['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UniversitySelectorScreen()),
        (route) => false,
      );
    } else {
      setState(() => _leaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not leave the waitlist')));
    }
  }

  Future<void> _logout() async {
    await SessionService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
            Icon(Icons.hourglass_top_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'You\'re on the list',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ll email you the moment UniVerse launches at ${widget.universityName}. No need to keep checking back.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _leaving ? null : _leaveWaitlist,
              child: _leaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Text('Leave Waitlist'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _leaving ? null : _logout,
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
