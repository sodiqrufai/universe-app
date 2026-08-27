import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _chat = true;
  bool _marketplace = true;
  bool _events = true;
  bool _community = true;
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
        _chat = settings['notify_chat'] ?? true;
        _marketplace = settings['notify_marketplace'] ?? true;
        _events = settings['notify_events'] ?? true;
        _community = settings['notify_community'] ?? true;
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
      'notify_chat': _chat,
      'notify_marketplace': _marketplace,
      'notify_events': _events,
      'notify_community': _community,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Chat messages'),
            value: _chat,
            onChanged: (v) => setState(() => _chat = v),
          ),
          SwitchListTile(
            title: const Text('Marketplace offers'),
            value: _marketplace,
            onChanged: (v) => setState(() => _marketplace = v),
          ),
          SwitchListTile(
            title: const Text('Events'),
            value: _events,
            onChanged: (v) => setState(() => _events = v),
          ),
          SwitchListTile(
            title: const Text('Community activity'),
            value: _community,
            onChanged: (v) => setState(() => _community = v),
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