import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

const _seenOnboardingKey = 'has_seen_onboarding';

/// Checks the persisted flag once and returns whether onboarding
/// should be shown — used by SplashScreen before deciding between
/// OnboardingScreen and LoginScreen.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_seenOnboardingKey) ?? false;
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingSlide({required this.icon, required this.title, required this.body});
}

/// First-time-install-only intro. Shown once, then never again — the
/// "seen" flag persists locally via SharedPreferences.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.school,
      title: 'Everything campus, one app',
      body: 'Courses, events, marketplace, and services — all built around your university.',
    ),
    _OnboardingSlide(
      icon: Icons.forum_outlined,
      title: 'Say what\'s on your mind',
      body: 'Post to your campus feed, or share anonymously in a space that\'s actually safe.',
    ),
    _OnboardingSlide(
      icon: Icons.verified_user_outlined,
      title: 'Verified students only',
      body: 'Every student on UniVerse is verified — so you know who you\'re really talking to.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) => _buildSlide(_slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ElevatedButton(
                onPressed: () {
                  if (_page == _slides.length - 1) {
                    _finish();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(_page == _slides.length - 1 ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(color: AppColors.lightPurple, shape: BoxShape.circle),
            child: Icon(slide.icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
