import '../../config/api_config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  File? _image;
  String _visibility = 'university';
  bool _posting = false;
  String? _error;

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

    final token = await SessionService.getToken();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/posts'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = _contentController.text.trim();
      request.fields['visibility'] = _visibility;
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
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to post';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
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
        padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_image!, height: 200, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 16),
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
                  style: TextStyle(fontSize: 13, color: Colors.black54),
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
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

