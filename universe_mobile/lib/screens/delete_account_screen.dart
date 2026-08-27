import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  bool _deleting = false;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
    });
    final data = await ApiService.delete('/profile/account');
    if (data['success'] == true) {
      await SessionService.clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _deleting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to delete account')),
        );
      }
    }
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _confirmController.text.trim().toUpperCase() == 'DELETE';
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'This permanently deletes your account and all your data — posts, messages, listings, everything. This cannot be undone.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            Text(
              'Type DELETE to confirm',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: canDelete && !_deleting ? _delete : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Permanently Delete My Account'),
            ),
          ],
        ),
      ),
    );
  }
}
