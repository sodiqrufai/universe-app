import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../widgets/restricted_dialog.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  File? _image;
  String _visibility = 'university';
  bool _posting = false;
  String? _error;
  final List<String> _tags = [];

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.contains(tag) || _tags.length >= 5) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) {
      setState(() {
        _error = 'Write something before posting';
      });
      return;
    }

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      final token = await SessionService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/posts'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = _contentController.text.trim();
      request.fields['visibility'] = _visibility;
      if (_tags.isNotEmpty) request.fields['tags'] = _tags.join(',');
      if (_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', _image!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        if (mounted) Navigator.of(context).pop(true);
      } else if (response.statusCode == 403) {
        final message = data['message'] ?? data['error'] ?? 'This action is restricted on your account.';
        if (mounted) {
          await showRestrictedDialog(context, message is List ? message.join(', ') : message.toString());
        }
      } else {
        setState(() {
          _error = data['error'] ?? data['message'] ?? 'Failed to post';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not post — check your connection';
      });
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _submit,
            child: _posting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "What's happening on campus?",
                border: InputBorder.none,
              ),
            ),
            if (_image != null) ...[
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Image.file(_image!, height: 200, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Tags (optional, up to 5)',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _tagController,
              enabled: _tags.length < 5,
              decoration: InputDecoration(
                hintText: 'e.g. Exam Tips, Hostel Life',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _addTag(_tagController.text),
                ),
              ),
              onSubmitted: _addTag,
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map(
                      (t) => Chip(
                        label: Text(t),
                        backgroundColor: AppColors.lightPurple,
                        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
                        deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                        onDeleted: () => setState(() => _tags.remove(t)),
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(
                    Icons.image_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Visibility:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _visibility,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'university',
                      child: Text('My University'),
                    ),
                    DropdownMenuItem(
                      value: 'global',
                      child: Text('Global (all students)'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _visibility = v!),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
          ],
        ),
      ),
    );
  }
}
