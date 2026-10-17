import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/telemetry.dart';
import '../utils/upload_rules.dart';

class VerificationScreen extends StatefulWidget {
  // isReupload only changes the confirmation copy shown on success.
  // onSubmitted is used when this screen is embedded directly (the
  // never-submitted case, not pushed as its own route) -- there's nothing
  // to Navigator.pop back to in that case, so the parent needs a callback
  // instead to know when to refresh. When this screen IS pushed as its own
  // route (the reupload case), it still also pops with `true` so callers
  // using the push-based pattern keep working.
  final bool isReupload;
  final VoidCallback? onSubmitted;

  const VerificationScreen({super.key, this.isReupload = false, this.onSubmitted});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _fullNameController = TextEditingController();
  final _matricController = TextEditingController();
  Uint8List? _documentBytes;
  String? _documentName;
  bool _submitting = false;
  String? _error;
  // True only when the last failure came from the submission itself.
  bool _retryable = false;

  Future<void> _pickDocument() async {
    if (_submitting) return;
    // Student ID photos follow the image rules: JPG/PNG/WebP, up to 8MB.
    final result = await UploadPicker.pickImage(quality: 85);
    if (!mounted || result.cancelled) return;
    if (result.error != null) {
      setState(() {
        _error = result.error;
        _retryable = false;
      });
      return;
    }
    setState(() {
      _documentBytes = result.file!.bytes;
      _documentName = result.file!.name;
      _error = null;
      _retryable = false;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_fullNameController.text.trim().isEmpty ||
        _matricController.text.trim().isEmpty ||
        _documentBytes == null) {
      setState(() {
        _error = 'Please fill in all fields and upload your student ID';
        _retryable = false;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _retryable = false;
    });

    try {
      final profileData = await ApiService.get('/profile/me');
      if (profileData['success'] != true) {
        if (mounted) {
          setState(() {
            _error = (profileData['error'] ?? "Couldn't load your profile. Please try again.").toString();
            _retryable = true;
          });
        }
        return;
      }
      final universityId = profileData['profile']?['university_id'];
      if (universityId == null) {
        if (mounted) {
          setState(() {
            _error = 'No university found on your profile. Please complete onboarding first.';
            _retryable = false;
          });
        }
        return;
      }

      final data = await UploadApi.send(
        '/verification/submit',
        fields: {
          'fullName': _fullNameController.text.trim(),
          'matricNumber': _matricController.text.trim(),
          'universityId': universityId.toString(),
        },
        files: [
          UploadFile(
            field: 'file',
            bytes: _documentBytes!,
            name: _documentName ?? 'student_id.jpg',
          ),
        ],
      );

      if (data['success'] == true) {
        Telemetry.track('verification_submitted', {'reupload': widget.isReupload});
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(Icons.check_circle, color: AppColors.success, size: 40),
            title: Text(widget.isReupload ? 'Verification resubmitted' : 'Submitted!'),
            content: Text(
              widget.isReupload
                  ? 'Your new document is back under review. Reviews usually take 1 to 2 working days. Open Account Verification any time to see where it stands.'
                  : 'Your student ID is now under review. Reviews usually take 1 to 2 working days. Open Account Verification any time to see where it stands.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        widget.onSubmitted?.call();
        // Only pop when this screen was pushed as its own route (the
        // profile/settings entry points, and the reupload flow). When
        // embedded directly as VerificationStatusScreen's body (the
        // never-submitted case), onSubmitted is how the parent finds out
        // instead: popping here would close the parent screen entirely
        // rather than just refreshing its content.
        if (widget.onSubmitted == null && mounted) {
          Navigator.of(context).pop(true);
        }
      } else if (mounted) {
        setState(() {
          _error = (data['error'] ?? 'Submission failed. Please try again.').toString();
          _retryable = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Submission failed. Please try again.';
          _retryable = true;
        });
      }
    } finally {
      // Never leave the Submit button spinning.
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _matricController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Student Status')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Get Verified',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isReupload
                  ? 'Upload a clearer photo of your student ID and we will review it again.'
                  : 'Upload your student ID to unlock the verified badge and full platform access.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Tips for a quick approval:\n'
                '• Your name and matric number must be readable\n'
                '• Use a JPG, PNG or WebP photo, up to 8MB\n'
                '• A real student ID card, not a screenshot of an app\n\n'
                'A person at UniVerse checks every submission, usually within 1 to 2 working days.',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name (as on your ID)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _matricController,
              decoration: const InputDecoration(
                labelText: 'Matriculation Number',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickDocument,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: _documentBytes == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              size: 40,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 8),
                            Text('Tap to upload your Student ID'),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          _documentBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            if (_submitting)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Uploading your ID. This can take a moment on a slow connection.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: UploadErrorBox(
                  message: _error!,
                  onRetry: (_retryable && !_submitting) ? _submit : null,
                ),
              ),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Submit for Verification'),
            ),
          ],
        ),
      ),
    );
  }
}

