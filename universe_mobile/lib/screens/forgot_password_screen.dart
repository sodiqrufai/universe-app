import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _isError = false;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );
      final data = jsonDecode(response.body);

      setState(() {
        if (data['success'] == true) {
          _message = 'If that email exists, a reset link has been sent.';
          _isError = false;
        } else {
          _message = data['error'] ?? 'Something went wrong';
          _isError = true;
        }
      });
    } catch (e) {
      setState(() {
        _message = 'Could not connect: $e';
        _isError = true;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Forgot your password?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your email and we\'ll send you a reset link.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 24),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _message!,
                  style: TextStyle(color: _isError ? Colors.red : AppColors.success),
                ),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }
}