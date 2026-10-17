import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../utils/upload_rules.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  DateTime? _startsAt;
  Uint8List? _coverBytes;
  String? _coverName;
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
    final data = await ApiService.get('/events/categories');
    if (!mounted) return;
    if (data['success'] == true) {
      setState(() {
        _categories = data['categories'] ?? [];
      });
    }
  }

  Future<void> _pickCover() async {
    if (_submitting) return;
    final result = await UploadPicker.pickImage();
    if (!mounted || result.cancelled) return;
    if (result.error != null) {
      setState(() {
        _error = result.error;
        _retryable = false;
      });
      return;
    }
    setState(() {
      _coverBytes = result.file!.bytes;
      _coverName = result.file!.name;
      _error = null;
      _retryable = false;
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_titleController.text.trim().isEmpty || _startsAt == null) {
      setState(() {
        _error = 'Title and date/time are required';
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
        '/events',
        fields: {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'location': _locationController.text.trim(),
          'startsAt': _startsAt!.toUtc().toIso8601String(),
          'categoryId': ?_selectedCategoryId,
        },
        files: [
          if (_coverBytes != null)
            UploadFile(
              field: 'cover',
              bytes: _coverBytes!,
              name: _coverName ?? 'cover.jpg',
            ),
        ],
      );

      if (data['success'] == true) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (mounted) {
        setState(() {
          _error = (data['error'] ?? 'Could not create your event. Please try again.').toString();
          _retryable = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not create your event. Please try again.';
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
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
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
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _coverBytes == null
                    ? Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          _coverBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Event Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.calendar_today_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                _startsAt == null ? 'Pick date & time' : _startsAt.toString(),
              ),
              onTap: _pickDateTime,
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
            if (_submitting)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _coverBytes == null ? 'Posting…' : 'Uploading your cover photo and posting…',
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

