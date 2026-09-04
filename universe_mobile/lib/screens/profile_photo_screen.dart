import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/step_progress_dots.dart';
import '../models/profile_setup_data.dart';
import '../services/session_service.dart';
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    }
  }

  Future<void> _continue() async {
    if (_imageBytes == null) {
      _goNext();
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final token = await SessionService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/profile/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('file', _imageBytes!, filename: _imageName));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        _goNext();
      } else if (mounted) {
        setState(() {
          _error = data['error'] ?? 'Could not upload photo';
          _uploading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not upload photo — check your connection';
          _uploading = false;
        });
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
            const Text(
              'Add a profile photo',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help other students recognize you. You can always add this later.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.lightPurple,
                      backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                      child: _imageBytes == null
                          ? const Icon(Icons.person, size: 60, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
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
          ],
        ),
      ),
    );
  }
}
