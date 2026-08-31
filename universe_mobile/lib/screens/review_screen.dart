import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import '../widgets/step_progress_dots.dart';
import 'main_shell.dart';

/// Step 12 of 12: Review & Continue. Everything was already saved
/// progressively at each prior step — this just confirms it landed
/// correctly before dropping the new student into the app.
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

    final rows = <(IconData, String, String?)>[
      (Icons.person_outline, 'Name', _profile!['full_name']),
      (Icons.alternate_email, 'Username', _profile!['username'] != null ? '@${_profile!['username']}' : null),
      (Icons.school_outlined, 'University', _profile!['universities']?['name']),
      (Icons.account_balance_outlined, 'Faculty', _profile!['faculties']?['name']),
      (Icons.corporate_fare_outlined, 'Department', _profile!['departments']?['name']),
      (Icons.grade_outlined, 'Level', _profile!['level']),
      (Icons.info_outline, 'Bio', (_profile!['bio']?.toString().isNotEmpty ?? false) ? _profile!['bio'] : 'Not added'),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.lightPurple,
            backgroundImage: _profile!['avatar_url'] != null
                ? NetworkImage(_profile!['avatar_url'])
                : null,
            child: _profile!['avatar_url'] == null
                ? const Icon(Icons.person, size: 44, color: AppColors.primary)
                : null,
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
