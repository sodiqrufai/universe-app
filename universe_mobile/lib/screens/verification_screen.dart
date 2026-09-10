import '../config/api_config.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';

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

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _documentBytes = bytes;
        _documentName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_fullNameController.text.trim().isEmpty ||
        _matricController.text.trim().isEmpty ||
        _documentBytes == null) {
      setState(() {
        _error = 'Please fill in all fields and upload your student ID';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final token = await SessionService.getToken();
    final profileData = await ApiService.get('/profile/me');
    final universityId = profileData['profile']?['university_id'];

    if (universityId == null) {
      setState(() {
        _error =
            'No university found on your profile. Please complete onboarding first.';
        _submitting = false;
      });
      return;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/verification/submit'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['fullName'] = _fullNameController.text.trim();
      request.fields['matricNumber'] = _matricController.text.trim();
      request.fields['universityId'] = universityId;
      request.files.add(
        http.MultipartFile.fromBytes('file', _documentBytes!, filename: _documentName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              icon: Icon(Icons.check_circle, color: AppColors.success, size: 40),
              title: Text(widget.isReupload ? 'Verification resubmitted' : 'Submitted!'),
              content: Text(
                widget.isReupload
                    ? 'Your document has been resubmitted and is back under review.'
                    : 'Your student ID has been submitted and is now under review.',
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
          // instead -- popping here would incorrectly close the parent
          // screen entirely rather than just refreshing its content.
          if (widget.onSubmitted == null && mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        setState(() {
          _error = data['error'] ?? 'Submission failed';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
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
              'Upload your student ID to unlock the verified badge and full platform access.',
              style: TextStyle(color: AppColors.textSecondary),
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: TextStyle(color: AppColors.error)),
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

