import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../utils/upload_rules.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String _condition = 'good';
  // Each entry pairs the picked image's bytes with its filename, since
  // there's no dart:io File to carry both on web.
  final List<(Uint8List bytes, String name)> _images = [];
  bool _submitting = false;
  String? _error;
  // True only when the last failure came from the upload itself.
  bool _retryable = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    // Categories are optional, so a failure here doesn't block posting.
    final data = await ApiService.get('/marketplace/categories');
    if (!mounted) return;
    if (data['success'] == true) {
      setState(() {
        _categories = data['categories'] ?? [];
      });
    }
  }

  Future<void> _pickImages() async {
    if (_submitting) return;
    final remaining = UploadRules.maxListingImages - _images.length;
    if (remaining <= 0) return;
    final result = await UploadPicker.pickImages(remaining: remaining);
    if (!mounted) return;
    setState(() {
      for (final f in result.files) {
        _images.add((f.bytes, f.name));
      }
      // Photos that were fine are kept; the first rejected one is explained
      // (e.g. "That image is 9.2MB. The limit is 8MB.").
      _error = result.error;
      _retryable = false;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_titleController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      setState(() {
        _error = 'Title and price are required';
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
      final data = await UploadApi.send(
        '/marketplace/listings',
        fields: {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'price': _priceController.text.trim(),
          'condition': _condition,
          if (_selectedCategoryId != null) 'categoryId': _selectedCategoryId!,
        },
        files: [
          for (final image in _images)
            UploadFile(field: 'images', bytes: image.$1, name: image.$2),
        ],
      );

      if (data['success'] == true) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (mounted) {
        setState(() {
          _error = (data['error'] ?? 'Could not create your listing. Please try again.').toString();
          _retryable = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not create your listing. Please try again.';
          _retryable = true;
        });
      }
    } finally {
      // Never leave the Post button spinning.
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Listing'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < _images.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _images[i].$1,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: _submitting
                                  ? null
                                  : () => setState(() => _images.removeAt(i)),
                              child: Semantics(
                                button: true,
                                label: 'Remove photo ${i + 1}',
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_images.length < UploadRules.maxListingImages)
                    GestureDetector(
                      onTap: _submitting ? null : _pickImages,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (₦)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map<DropdownMenuItem<String>>((c) {
                return DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(c['name']),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: ['new', 'like_new', 'good', 'fair', 'used'].map((c) {
                return DropdownMenuItem(value: c, child: Text(c));
              }).toList(),
              onChanged: (v) => setState(() => _condition = v!),
            ),
            if (_submitting)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _images.isEmpty ? 'Posting…' : 'Uploading your photos and posting…',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: UploadErrorBox(
                  message: _error!,
                  onRetry: (_retryable && !_submitting) ? _submit : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

