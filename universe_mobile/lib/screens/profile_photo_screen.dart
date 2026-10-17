import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/profile_setup_data.dart';
import '../utils/upload_rules.dart';
import 'bio_screen.dart';

/// Step 6 of 12: Profile Photo (optional). Avatar upload still happens
/// immediately here (unlike username/bio/level, a photo isn't part of
/// the "half-saved profile" risk the backend's complete-setup endpoint
/// guards against, so there's no reason to defer it). Also reused as
/// an edit entry point from ReviewScreen (editMode: true), popping
/// back instead of continuing to BioScreen.
class ProfilePhotoScreen extends StatefulWidget {
  final ProfileSetupData setupData;
  final bool editMode;
  const ProfilePhotoScreen({super.key, required this.setupData, this.editMode = false});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  Uint8List? _imageBytes;
  String? _imageName;
  bool _uploading = false;
  String? _error;

  Future<void> _pickImage() async {
    if (_uploading) return;
    final result = await UploadPicker.pickImage(quality: 85);
    if (!mounted || result.cancelled) return;
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    setState(() {
      _imageBytes = result.file!.bytes;
      _imageName = result.file!.name;
      _error = null;
    });
  }

  Future<void> _continue() async {
    if (_uploading) return;
    if (_imageBytes == null) {
      _goNext();
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final data = await UploadApi.send(
        '/profile/avatar',
        files: [
          UploadFile(field: 'file', bytes: _imageBytes!, name: _imageName ?? 'avatar.jpg'),
        ],
      );

      if (data['success'] == true) {
        // Leave _uploading as is: the screen is about to be replaced. If it
        // is still mounted (it should not be), the finally block resets it.
        _goNext();
      } else if (mounted) {
        setState(() {
          _error = (data['error'] ?? 'Could not upload your photo. Please try again.').toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not upload your photo. Please try again.';
        });
      }
    } finally {
      // Never leave the button spinning (e.g. if navigation did not happen).
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _goNext() {
    if (!mounted) return;
    if (widget.editMode) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BioScreen(setupData: widget.setupData)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editMode ? 'Edit Photo' : 'Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.editMode) ...[
              const StepProgressDots(currentStep: 6, totalSteps: 12),
              const SizedBox(height: 24),
            ],
            Text(
              'Add a profile photo',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Help other students recognize you. You can always add this later.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                onTap: _uploading ? null : _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.lightPurple,
                      backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                      child: _imageBytes == null
                          ? Icon(Icons.person, size: 60, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_uploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Uploading your photo…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: UploadErrorBox(
                  message: _error!,
                  // Retry only makes sense once a photo is chosen. Skipping
                  // is always possible too: the photo is optional.
                  onRetry: (_imageBytes != null && !_uploading) ? _continue : null,
                ),
              ),
            ElevatedButton(
              onPressed: _uploading ? null : _continue,
              child: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_imageBytes != null ? 'Continue' : (widget.editMode ? 'Back' : 'Skip for now')),
            ),
            if (_error != null && _imageBytes != null && !widget.editMode)
              TextButton(
                onPressed: _uploading ? null : _goNext,
                child: const Text('Skip for now'),
              ),
          ],
        ),
      ),
    );
  }
}
