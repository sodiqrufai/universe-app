import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import '../widgets/step_progress_dots.dart';
import '../models/sign_up_data.dart';
import '../models/profile_setup_data.dart';
import 'main_shell.dart';
import 'name_screen.dart';
import 'username_screen.dart';
import 'profile_photo_screen.dart';
import 'bio_screen.dart';
import 'university_selector_screen.dart';
import 'faculty_selector_screen.dart';
import 'department_selector_screen.dart';
import 'level_selector_screen.dart';

/// Step 12 of 12: Review & Continue. Everything was already saved
/// progressively at each prior step — this just confirms it landed
/// correctly before dropping the new student into the app.
///
/// Also doubles as a lightweight profile-edit hub: every field has an
/// edit icon that pushes the same screen used during sign-up, in
/// editMode — each of those already knows how to save on its own and
/// pop back rather than continue forward through the rest of the
/// chain, so this screen just needs to push and refresh on return.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/profile/me');
      if (data['success'] == true) {
        setState(() {
          _profile = data['profile'];
          _loading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  /// Pushes an edit-mode step screen and refreshes the profile if it
  /// reports a save (pop(true)) on the way back — pop() with no
  /// argument (back button, cancel) refreshes nothing, matching a
  /// discarded edit.
  Future<void> _edit(Widget screen) async {
    final changed = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    if (changed == true) _fetchProfile();
  }

  ProfileSetupData get _currentSetupData => ProfileSetupData(
    username: _profile?['username'] ?? '',
    bio: _profile?['bio'] ?? '',
  );

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('You\'re all set')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: StepProgressDots(currentStep: 12, totalSteps: 12),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError || _profile == null) {
      return ErrorView(message: 'Could not load your profile', onRetry: _fetchProfile);
    }

    final rows = <(IconData, String, String?, VoidCallback)>[
      (
        Icons.person_outline,
        'Name',
        _profile!['full_name'],
        () => _edit(NameScreen(
          data: SignUpData(fullName: _profile!['full_name'] ?? ''),
          editMode: true,
        )),
      ),
      (
        Icons.alternate_email,
        'Username',
        _profile!['username'] != null ? '@${_profile!['username']}' : null,
        () => _edit(UsernameScreen(
          data: SignUpData(username: _profile!['username'] ?? ''),
          editMode: true,
        )),
      ),
      (
        Icons.school_outlined,
        'University',
        _profile!['universities']?['name'],
        () => _edit(UniversitySelectorScreen(setupData: _currentSetupData, editMode: true)),
      ),
      (
        Icons.account_balance_outlined,
        'Faculty',
        _profile!['faculties']?['name'],
        () => _edit(FacultySelectorScreen(
          universityId: _profile!['university_id'],
          setupData: _currentSetupData,
          editMode: true,
        )),
      ),
      (
        Icons.corporate_fare_outlined,
        'Department',
        _profile!['departments']?['name'],
        () => _edit(DepartmentSelectorScreen(
          facultyId: _profile!['faculty_id'],
          setupData: _currentSetupData,
          editMode: true,
        )),
      ),
      (
        Icons.grade_outlined,
        'Level',
        _profile!['level'],
        () => _edit(LevelSelectorScreen(setupData: _currentSetupData, editMode: true)),
      ),
      (
        Icons.info_outline,
        'Bio',
        (_profile!['bio']?.toString().isNotEmpty ?? false) ? _profile!['bio'] : 'Not added',
        () => _edit(BioScreen(setupData: _currentSetupData, editMode: true)),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.lightPurple,
                backgroundImage: _profile!['avatar_url'] != null
                    ? NetworkImage(_profile!['avatar_url'])
                    : null,
                child: _profile!['avatar_url'] == null
                    ? const Icon(Icons.person, size: 44, color: AppColors.primary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Semantics(
                  button: true,
                  label: 'Edit photo',
                  child: GestureDetector(
                    onTap: () => _edit(
                      ProfilePhotoScreen(setupData: _currentSetupData, editMode: true),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.background, width: 2),
                        ),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Text(
          'Here\'s your profile',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                ListTile(
                  leading: Icon(rows[i].$1, color: AppColors.primary, size: 20),
                  title: Text(rows[i].$2, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  subtitle: Text(
                    rows[i].$3 ?? '—',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                    tooltip: 'Edit ${rows[i].$2}',
                    onPressed: rows[i].$4,
                  ),
                ),
                if (i != rows.length - 1) const Divider(height: 1, indent: 56, color: AppColors.border),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(onPressed: _finish, child: const Text('Continue to UniVerse')),
      ],
    );
  }
}
