import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AnonymousUsernameScreen extends StatefulWidget {
  const AnonymousUsernameScreen({super.key});

  @override
  State<AnonymousUsernameScreen> createState() => _AnonymousUsernameScreenState();
}

class _AnonymousUsernameScreenState extends State<AnonymousUsernameScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _hasIdentity = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.get('/anonymous/profile');
      final profile = data['profile'];
      setState(() {
        _hasIdentity = profile != null;
        if (profile != null) _controller.text = profile['anonymous_username'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = await ApiService.patch('/anonymous/profile', {'username': _controller.text.trim()});
    if (data['success'] == true) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username updated')));
    } else {
      setState(() {
        _error = data['error'] ?? 'Failed to update';
      });
    }
    setState(() {
      _saving = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Anonymous Identity')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_hasIdentity)
              const Text("You haven't created an anonymous identity yet. Post anonymously to set one up.")
            else ...[
              TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Anonymous Username'),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Update Username'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}