import '../../config/api_config.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';

class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String _priceType = 'fixed';
  // Each entry pairs the picked image's bytes with its filename, since
  // there's no dart:io File to carry both on web.
  final List<(Uint8List bytes, String name)> _images = [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/services/categories'),
      );
      final data = jsonDecode(response.body);
      setState(() {
        _categories = data['categories'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      final toAdd = picked.take(6 - _images.length);
      final withBytes = await Future.wait(
        toAdd.map((x) async => (bytes: await x.readAsBytes(), name: x.name)),
      );
      setState(() {
        _images.addAll(withBytes.map((e) => (e.bytes, e.name)));
      });
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _error = 'Title is required';
      });
      return;
    }
    if (_priceType != 'negotiable' && _priceController.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter a price, or choose Negotiable';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final token = await SessionService.getToken();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/services/listings'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descController.text.trim();
      request.fields['price'] = _priceType == 'negotiable'
          ? ''
          : _priceController.text.trim();
      request.fields['priceType'] = _priceType;
      if (_selectedCategoryId != null) {
        request.fields['categoryId'] = _selectedCategoryId!;
      }
      for (final image in _images) {
        request.files.add(
          http.MultipartFile.fromBytes('images', image.$1, filename: image.$2),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to create service';
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
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer a Service'),
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
                  ..._images.map(
                    (img) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          img.$1,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  if (_images.length < 6)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
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
              decoration: const InputDecoration(labelText: 'Service Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priceType,
              decoration: const InputDecoration(labelText: 'Pricing'),
              items: const [
                DropdownMenuItem(value: 'fixed', child: Text('Fixed price')),
                DropdownMenuItem(value: 'hourly', child: Text('Hourly rate')),
                DropdownMenuItem(
                  value: 'negotiable',
                  child: Text('Negotiable'),
                ),
              ],
              onChanged: (v) => setState(() => _priceType = v!),
            ),
            if (_priceType != 'negotiable') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (₦)'),
              ),
            ],
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

