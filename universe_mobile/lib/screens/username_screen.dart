import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/step_progress_dots.dart';
import '../models/sign_up_data.dart';
import 'create_password_screen.dart';

enum _CheckState { idle, checking, available, taken, formatError }

/// Step 3 of 12: Username.
///
/// GET /auth/check-username now exists (unauthenticated, so it works
/// before an account is created) — real live availability checking,
/// debounced as the user types. Also reused as an edit entry point
/// from ReviewScreen (editMode: true), saving via PATCH /profile/update
/// and popping back instead of continuing to CreatePasswordScreen.
class UsernameScreen extends StatefulWidget {
  final SignUpData data;
  final bool editMode;
  const UsernameScreen({super.key, required this.data, this.editMode = false});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  late final _usernameController = TextEditingController(text: widget.data.username);
  _CheckState _state = _CheckState.idle;
  String? _formatMessage;
  Timer? _debounce;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Edit mode opens with the already-saved, already-valid username —
    // no reason to force a re-check before Continue is tappable.
    if (widget.editMode && widget.data.username.isNotEmpty) {
      _state = _CheckState.available;
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final username = value.trim();

    if (username.isEmpty) {
      setState(() {
        _state = _CheckState.idle;
        _formatMessage = null;
      });
      return;
    }
    if (!_usernameRegex.hasMatch(username)) {
      setState(() {
        _state = _CheckState.formatError;
        _formatMessage = '3-20 characters: letters, numbers, underscores only';
      });
      return;
    }

    setState(() {
      _state = _CheckState.checking;
      _formatMessage = null;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () => _checkAvailability(username));
  }

  Future<void> _checkAvailability(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/check-username?u=$username'),
      );
      final data = jsonDecode(response.body);
      if (!mounted || _usernameController.text.trim() != username) return; // stale response
      setState(() {
        _state = data['available'] == true ? _CheckState.available : _CheckState.taken;
        _formatMessage = data['available'] == true ? null : (data['error'] ?? 'That username is taken');
      });
    } catch (_) {
      if (mounted && _usernameController.text.trim() == username) {
        setState(() {
          _state = _CheckState.idle;
          _formatMessage = 'Could not check availability — you can still continue';
        });
      }
    }
  }

  Future<void> _continue() async {
    if (_state != _CheckState.available) return;

    if (!widget.editMode) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreatePasswordScreen(
            data: widget.data.copyWith(username: _usernameController.text.trim()),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final data = await ApiService.patch(
      '/profile/update',
      {'username': _usernameController.text.trim()},
    );
    if (!mounted) return;
    if (data['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _formatMessage = data['error'] ?? 'Could not save your username';
      });
    }
  }

  Widget _buildStatusIcon() {
    switch (_state) {
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
      appBar: AppBar(title: Text(widget.editMode ? 'Edit Username' : 'Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.editMode) ...[
              const StepProgressDots(currentStep: 3, totalSteps: 12),
              const SizedBox(height: 24),
            ],
            const Text(
              'Choose a username',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is your unique @handle on UniVerse.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: _onChanged,
              onSubmitted: (_) => _continue(),
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                prefixIcon: const Icon(Icons.alternate_email),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _buildStatusIcon(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_formatMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _formatMessage!,
                  style: TextStyle(
                    color: _state == _CheckState.idle ? AppColors.textSecondary : AppColors.error,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: (_state == _CheckState.available && !_saving) ? _continue : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
