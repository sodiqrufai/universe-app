import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  String _visibility = 'everyone';
  bool _allowMessages = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.get('/profile/settings');
      final settings = data['settings'];
      setState(() {
        _visibility = settings['profile_visibility'] ?? 'everyone';
        _allowMessages = settings['allow_messages'] ?? true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    await ApiService.patch('/profile/settings', {
      'profile_visibility': _visibility,
      'allow_messages': _allowMessages,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Privacy settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Who can see your profile', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<String>(
            title: const Text('Everyone'),
            value: 'everyone',
            groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v!),
          ),
          RadioListTile<String>(
            title: const Text('My university only'),
            value: 'university_only',
            groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v!),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Allow direct messages'),
            subtitle: const Text('Other students can message you'),
            value: _allowMessages,
            onChanged: (v) => setState(() => _allowMessages = v),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(onPressed: _save, child: const Text('Save Changes')),
          ),
        ],
      ),
    );
  }
}