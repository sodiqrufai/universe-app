import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../utils/upload_rules.dart';
import '../widgets/state_views.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;
  bool _loadFailed = false;
  String _loadError = '';
  String? _universityName;
  String? _avatarUrl;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final data = await ApiService.get('/profile/me');
      if (!mounted) return;
      if (data['success'] == true) {
        final profile = data['profile'];
        setState(() {
          _fullNameController.text = profile['full_name'] ?? '';
          _usernameController.text = profile['username'] ?? '';
          _bioController.text = profile['bio'] ?? '';
          _universityName = profile['universities']?['name'];
          _avatarUrl = profile['avatar_url'];
          _loading = false;
        });
      } else {
        setState(() {
          _loadError = (data['error'] ?? 'Could not load your profile.').toString();
          _loadFailed = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load your profile.';
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadingPhoto) return;
    final result = await UploadPicker.pickImage();
    if (!mounted || result.cancelled) return;
    if (result.error != null) {
      _toast(result.error!);
      return;
    }
    final file = result.file!;

    // Show the new photo straight away, but remember the old state so a
    // failed upload puts it back instead of pretending it worked.
    final previousBytes = _pickedImageBytes;
    setState(() {
      _pickedImageBytes = file.bytes;
      _uploadingPhoto = true;
    });

    try {
      final data = await UploadApi.send(
        '/profile/avatar',
        files: [UploadFile(field: 'file', bytes: file.bytes, name: file.name)],
      );

      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _avatarUrl = data['avatarUrl'] ?? _avatarUrl;
          });
        }
        _toast('Photo updated');
      } else {
        if (mounted) setState(() => _pickedImageBytes = previousBytes);
        _toast((data['error'] ?? 'Could not upload your photo. Please try again.').toString());
      }
    } catch (_) {
      if (mounted) setState(() => _pickedImageBytes = previousBytes);
      _toast('Could not upload your photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await ApiService.patch('/profile/update', {
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile updated')));
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        setState(() {
          _error = (data['error'] ?? 'Could not save your changes.').toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save your changes. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  ImageProvider? _avatarImage() {
    if (_pickedImageBytes != null) return MemoryImage(_pickedImageBytes!);
    if (_avatarUrl != null) return NetworkImage(_avatarUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _loadFailed
          ? ErrorView(message: _loadError, onRetry: _fetchProfile)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          backgroundImage: _avatarImage(),
                          child: _avatarImage() == null
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Semantics(
                            button: true,
                            label: 'Change profile photo',
                            child: GestureDetector(
                            onTap: _uploadingPhoto ? null : _pickAndUploadImage,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary,
                              child: _uploadingPhoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                            ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_universityName != null) ...[
                    Text(
                      _universityName!,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}

