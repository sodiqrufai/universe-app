import '../../config/api_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'anonymous_feed_screen.dart';

class AnonymousSetupScreen extends StatefulWidget {
  const AnonymousSetupScreen({super.key});

  @override
  State<AnonymousSetupScreen> createState() => _AnonymousSetupScreenState();
}

class _AnonymousSetupScreenState extends State<AnonymousSetupScreen> {
  final _usernameController = TextEditingController();
  String? _error;
  String? _hint;
  bool _checking = false;
  bool _creating = false;

  Future<void> _checkAvailability(String value) async {
    if (value.trim().length < 3) {
      setState(() {
        _hint = null;
      });
      return;
    }
    setState(() {
      _checking = true;
    });
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/anonymous/profile/check-username'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': value.trim()}),
      );
      final data = jsonDecode(response.body);
      setState(() {
        _hint = data['available'] == true
            ? 'Available!'
            : (data['error'] ?? 'Already taken');
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    final token = await SessionService.getToken();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/anonymous/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': _usernameController.text.trim()}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AnonymousFeedScreen()),
          );
        }
      } else {
        setState(() {
          _error = data['error'] ?? 'Failed to create identity';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anonymous')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.masks_outlined,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Speak freely. Stay anonymous.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a username no one can trace back to you. This identity is completely separate from your real profile.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              onChanged: _checkAvailability,
              decoration: InputDecoration(
                labelText: 'Anonymous Username',
                prefixIcon: const Icon(Icons.alternate_email),
                suffixIcon: _checking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _hint!,
                  style: TextStyle(
                    color: _hint == 'Available!'
                        ? AppColors.success
                        : Colors.red,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _creating ? null : _create,
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create Anonymous Identity'),
            ),
          ],
        ),
      ),
    );
  }
}

