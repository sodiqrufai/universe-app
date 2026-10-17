import '../widgets/universe_logo.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../services/server_status.dart';
import '../models/profile_setup_data.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'profile_photo_screen.dart';
import 'university_selector_screen.dart';
import 'faculty_selector_screen.dart';
import 'department_selector_screen.dart';
import 'level_selector_screen.dart';
import 'waitlist_holding_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// True when the startup calls failed for a reason that is NOT "your login
  /// is invalid" (no internet, server asleep/slow, server error). The user
  /// stays signed in and gets a Retry button instead of being dumped on the
  /// login screen or left with an endless spinner.
  bool _failed = false;
  String _failureMessage = '';

  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  /// Network trouble or a server-side problem: worth retrying, and says
  /// nothing about whether the saved login is still good.
  bool _isTransient(Map<String, dynamic> result) {
    final status = result['statusCode'];
    return result['networkError'] == true ||
        result['timedOut'] == true ||
        result['rateLimited'] == true ||
        (status is int && status >= 500);
  }

  void _showFailure(String message) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _failureMessage = message;
    });
  }

  Future<void> _checkSessionAndNavigate() async {
    if (_failed) {
      setState(() {
        _failed = false;
        _failureMessage = '';
      });
    }

    // Keep the splash visible for at least 2 s while the real work runs.
    final minimumSplash = Future<void>.delayed(const Duration(seconds: 2));
    final token = await SessionService.getToken();

    if (token == null) {
      await minimumSplash;
      if (!mounted) return;
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
      final results = await Future.wait([
        ApiService.get('/profile/me'),
        ApiService.get('/waitlist/status'),
      ]);
      await minimumSplash;
      final data = results[0];
      final waitlistData = results[1];

      if (!mounted) return;

      // Couldn't get a real answer: keep the session, offer Retry.
      if (_isTransient(data) || _isTransient(waitlistData)) {
        final failed = _isTransient(data) ? data : waitlistData;
        _showFailure(
          (failed['error'] as String?) ??
              "Couldn't reach UniVerse. Check your connection and try again.",
        );
        return;
      }

      if (data['success'] == true) {
        final profile = data['profile'];
        final waitlist = waitlistData['success'] == true && waitlistData['waitlisted'] == true
            ? waitlistData
            : null;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _resolveResumeScreen(profile, waitlist)),
        );
      } else {
        // The server answered and rejected the login: token invalid/expired
        // even after the refresh attempt.
        await SessionService.clear();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (_) {
      // Unexpected failure (not a login problem). Don't sign the user out.
      _showFailure("Something went wrong while starting UniVerse. Please try again.");
    }
  }

  /// Escape hatch on the failure screen: go to sign-in without clearing the
  /// saved session, so a later launch can still resume.
  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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
  Widget _resolveResumeScreen(Map<String, dynamic> profile, Map<String, dynamic>? waitlist) {
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

    // A waitlist entry means this user already tried to pick their
    // university and it wasn't piloted yet — university_id will be
    // null for them by definition (nothing was ever saved), so this
    // has to be checked before the university_id check below, or
    // they'd be sent right back to UniversitySelectorScreen and see
    // the exact same "not available yet" outcome again, indistinguishable
    // from the app being broken.
    //
    // This comes from a separate GET /waitlist/status call, not from
    // profile/me — the backend keeps waitlist status as its own
    // resource (waitlist_entries table) rather than folding it into
    // the profile response.
    if (waitlist != null) {
      return WaitlistHoldingScreen(universityName: waitlist['universityName'] ?? 'your university');
    }

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
      decoration: BoxDecoration(
        gradient: AppColors.splashGradient,
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.18),
                            blurRadius: 48,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const UniVerseLogo(size: 132, badge: true),
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
                          color: Color(0xFFE4DEFF),
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
                    const SizedBox(height: 32),
                    _buildStatusArea(),
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

  /// Space under the tagline: nothing normally, a "waking up" note when the
  /// server is slow, and a message with Retry when startup failed.
  Widget _buildStatusArea() {
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _failureMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkSessionAndNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
              ),
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: _goToLogin,
              child: const Text(
                'Go to sign in',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: ServerStatus.instance,
      builder: (context, _) {
        final waking = ServerStatus.instance.isWaking;
        // Fixed height so the logo doesn't jump when the note appears.
        return SizedBox(
          height: 40,
          child: waking
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Waking up the server...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                )
              : null,
        );
      },
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
