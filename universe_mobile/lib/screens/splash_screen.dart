import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'university_selector_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await SessionService.getToken();

    if (!mounted) return;

    if (token == null) {
      final seenOnboarding = await hasSeenOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => seenOnboarding ? const LoginScreen() : const OnboardingScreen(),
        ),
      );
      return;
    }

    try {
      final data = await ApiService.get('/profile/me');
      if (data['success'] == true) {
        final profile = data['profile'];
        final onboarded =
            profile['university_id'] != null &&
            profile['department_id'] != null &&
            profile['level'] != null;

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => onboarded
                ? const MainShell()
                : const UniversitySelectorScreen(),
          ),
        );
      } else {
        // Token invalid/expired even after refresh attempt.
        await SessionService.clear();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'UniVerse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        children: [
                          const TextSpan(text: 'One App. '),
                          TextSpan(
                            text: 'Every ',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: 'Student.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(false),
                    const SizedBox(width: 6),
                    _dot(true),
                    const SizedBox(width: 6),
                    _dot(false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(bool active) {
    return Container(
      width: active ? 10 : 8,
      height: active ? 10 : 8,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white38,
        shape: BoxShape.circle,
      ),
    );
  }
}
