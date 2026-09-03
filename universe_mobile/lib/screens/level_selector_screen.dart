import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/step_progress_dots.dart';
import '../models/profile_setup_data.dart';
import 'review_screen.dart';

enum _CheckState { idle, checking, available, taken, formatError }

/// Step 11 of 12: Level. Saves username + bio + level together via
/// PATCH /profile/complete-setup — a single batched write, specifically
/// so a saved username can never end up without a level (or vice
/// versa) if someone abandons partway.
///
/// If setupData.username arrives empty — which happens if someone
/// closed the app between account creation and this step, then resumed
/// via SplashScreen's incomplete-profile check — this screen also asks
/// for a username right here as a fallback, using the same live check.
class LevelSelectorScreen extends StatefulWidget {
  final ProfileSetupData setupData;
  final bool editMode;
  const LevelSelectorScreen({
    super.key,
    this.setupData = const ProfileSetupData(),
    this.editMode = false,
  });

  @override
  State<LevelSelectorScreen> createState() => _LevelSelectorScreenState();
}

class _LevelSelectorScreenState extends State<LevelSelectorScreen> {
  final List<String> _levels = ['100L', '200L', '300L', '400L', '500L', 'Postgraduate'];
  String? _error;
  bool _submitting = false;

  late final _usernameController = TextEditingController(text: widget.setupData.username);
  _CheckState _usernameState = _CheckState.idle;
  Timer? _debounce;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  bool get _needsUsername => widget.setupData.username.isEmpty;

  @override
  void initState() {
    super.initState();
    if (!_needsUsername) _usernameState = _CheckState.available;
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final username = value.trim();
    if (username.isEmpty) {
      setState(() => _usernameState = _CheckState.idle);
      return;
    }
    if (!_usernameRegex.hasMatch(username)) {
      setState(() => _usernameState = _CheckState.formatError);
      return;
    }
    setState(() => _usernameState = _CheckState.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () => _checkUsername(username));
  }

  Future<void> _checkUsername(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/check-username?u=$username'),
      );
      final data = jsonDecode(response.body);
      if (!mounted || _usernameController.text.trim() != username) return;
      setState(() {
        _usernameState = data['available'] == true ? _CheckState.available : _CheckState.taken;
      });
    } catch (_) {
      if (mounted && _usernameController.text.trim() == username) {
        setState(() => _usernameState = _CheckState.idle);
      }
    }
  }

  Future<void> _selectLevel(String level) async {
    if (_needsUsername && _usernameState != _CheckState.available) {
      setState(() => _error = 'Choose an available username first');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = await ApiService.patch('/profile/complete-setup', {
        'username': _needsUsername ? _usernameController.text.trim() : widget.setupData.username,
        'bio': widget.setupData.bio,
        'level': level,
      });
      if (data['success'] == true && mounted) {
        if (widget.editMode) {
          Navigator.of(context).pop(true);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReviewScreen()),
        );
      } else if (mounted) {
        setState(() {
          _error = data['error'] ?? 'Failed to save your profile';
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save your profile';
          _submitting = false;
        });
      }
    }
  }

  Widget _buildStatusIcon() {
    switch (_usernameState) {
      case _CheckState.checking:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        );
      case _CheckState.available:
        return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
      case _CheckState.taken:
      case _CheckState.formatError:
        return const Icon(Icons.cancel, color: AppColors.error, size: 20);
      case _CheckState.idle:
        return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editMode ? 'Edit Level' : 'Select Your Level')),
      body: Column(
        children: [
          if (!widget.editMode)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: StepProgressDots(currentStep: 11, totalSteps: 12),
            ),
          if (_needsUsername)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _usernameController,
                onChanged: _onUsernameChanged,
                decoration: InputDecoration(
                  labelText: 'Choose a username',
                  prefixText: '@',
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: Padding(padding: const EdgeInsets.all(14), child: _buildStatusIcon()),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _levels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final level = _levels[index];
                return Card(
                  child: ListTile(
                    enabled: !_submitting,
                    leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                    title: Text(level),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectLevel(level),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
