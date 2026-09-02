import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../models/profile_setup_data.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'profile_photo_screen.dart';
import 'university_selector_screen.dart';
import 'faculty_selector_screen.dart';
import 'department_selector_screen.dart';
import 'level_selector_screen.dart';
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

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _resolveResumeScreen(profile)),
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

  /// Inspects the fetched profile in the same order as the onboarding
  /// chain itself (Photo → Bio → University → Faculty → Department →
  /// Level → Review) and resumes at the first genuinely incomplete
  /// step, rather than the old single `onboarded` boolean that only
  /// checked university/department/level and silently dropped anyone
  /// back to step 8 no matter how much further they'd actually gotten.
  ///
  /// Username is intentionally NOT its own early check here even
  /// though it's asked for before avatar/university in the step order
  /// everywhere else — a resumed, already-authenticated session can
  /// never legitimately reach UsernameScreen (that screen only exists
  /// pre-account, and chains onward into /auth/register, which would
  /// attempt to re-register an existing account). Missing username
  /// always means "abandoned somewhere in Photo..Level", so it's
  /// folded into the Level check at the end — LevelSelectorScreen
  /// already has its own username fallback field for exactly this
  /// case, matching the backend's complete-setup contract that saves
  /// username + level together.
  ///
  /// Every screen below is constructed with a ProfileSetupData built
  /// from the live fetch, not the default empty one, so a session
  /// resumed midway through University..Level still carries the real
  /// username/bio forward to the eventual batched save at Level.
  Widget _resolveResumeScreen(Map<String, dynamic> profile) {
    final setupData = ProfileSetupData(
      username: profile['username'] ?? '',
      bio: profile['bio'] ?? '',
    );

    // No persisted "skipped" signal exists on the backend yet for
    // avatar — this reads a field that doesn't exist there today, so
    // it defaults to false (not skipped) until that column is added.
    // Wired this way rather than treating avatar as unconditionally
    // non-blocking so it starts working the moment the field exists,
    // with no frontend change needed.
    final avatarSkipped = profile['avatarSkipped'] == true;
    if (profile['avatar_url'] == null && !avatarSkipped) {
      return ProfilePhotoScreen(setupData: setupData);
    }

    // Bio is optional — never blocks resume, always treated as satisfied.

    if (profile['university_id'] == null) {
      return UniversitySelectorScreen(setupData: setupData);
    }
    if (profile['faculty_id'] == null) {
      return FacultySelectorScreen(
        universityId: profile['university_id'],
        setupData: setupData,
      );
    }
    if (profile['department_id'] == null) {
      return DepartmentSelectorScreen(
        facultyId: profile['faculty_id'],
        setupData: setupData,
      );
    }
    if (profile['username'] == null || profile['level'] == null) {
      return LevelSelectorScreen(setupData: setupData);
    }

    // Everything's already set — this is a normal returning user, not
    // someone mid-onboarding. Straight into the app, not the "You're
    // all set" review screen (that's only ever reached once, directly
    // from LevelSelectorScreen finishing in the same session).
    return const MainShell();
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
