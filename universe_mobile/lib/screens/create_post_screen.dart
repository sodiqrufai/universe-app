import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/telemetry.dart';
import '../utils/upload_rules.dart';
import '../widgets/restricted_dialog.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  String _visibility = 'university';
  bool _posting = false;
  String? _error;
  // True only when the last failure came from the upload itself, so "Try
  // again" is not offered for things like a rejected photo.
  bool _retryable = false;
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
    if (_posting) return;
    final result = await UploadPicker.pickImage();
    if (!mounted || result.cancelled) return;
    if (result.error != null) {
      // Keep any image that was already chosen; just explain why this one
      // was refused ("That image is 9.2MB. The limit is 8MB.").
      setState(() {
        _error = result.error;
        _retryable = false;
      });
      return;
    }
    setState(() {
      _imageBytes = result.file!.bytes;
      _imageName = result.file!.name;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_posting) return;
    if (_contentController.text.trim().isEmpty) {
      setState(() {
        _error = 'Write something before posting';
        _retryable = false;
      });
      return;
    }

    setState(() {
      _posting = true;
      _error = null;
      _retryable = false;
    });

    try {
      final data = await UploadApi.send(
        '/posts',
        fields: {
          'content': _contentController.text.trim(),
          'visibility': _visibility,
          if (_tags.isNotEmpty) 'tags': _tags.join(','),
        },
        files: [
          if (_imageBytes != null)
            UploadFile(
              field: 'file',
              bytes: _imageBytes!,
              name: _imageName ?? 'post.jpg',
            ),
        ],
      );

      if (data['success'] == true) {
        Telemetry.track('post_created', {'has_image': _imageBytes != null});
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (!mounted) return;
      if (data['restricted'] == true) {
        await showRestrictedDialog(
          context,
          (data['error'] ?? 'This action is restricted on your account.').toString(),
        );
      } else {
        setState(() {
          _error = (data['error'] ?? 'Could not post. Please try again.').toString();
          _retryable = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not post. Please try again.';
          _retryable = true;
        });
      }
    } finally {
      // Never leave the Post button spinning.
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
            if (_imageBytes != null) ...[
              const SizedBox(height: AppSpacing.md),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Image.memory(
                      _imageBytes!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      tooltip: 'Remove image',
                      onPressed: _posting
                          ? null
                          : () => setState(() {
                                _imageBytes = null;
                                _imageName = null;
                              }),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
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
                  icon: Icon(Icons.add, color: AppColors.primary),
                  tooltip: 'Add tag',
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
                        labelStyle: TextStyle(color: AppColors.primary, fontSize: 12),
                        deleteIcon: Icon(Icons.close, size: 14, color: AppColors.primary),
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
                  onPressed: _posting ? null : _pickImage,
                  tooltip: 'Add image',
                  icon: Icon(
                    Icons.image_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
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
            if (_posting)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  _imageBytes != null ? 'Uploading your photo and posting…' : 'Posting…',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: UploadErrorBox(
                  message: _error!,
                  onRetry: (_retryable && !_posting) ? _submit : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
