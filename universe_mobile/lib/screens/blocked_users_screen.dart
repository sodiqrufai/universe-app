import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.get('/profile/blocked-users');
      setState(() {
        _blocked = data['blocked'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _unblock(String blockedId) async {
    await ApiService.delete('/chat/block/$blockedId');
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _blocked.isEmpty
          ? const Center(child: Text("You haven't blocked anyone"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _blocked.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final b = _blocked[index];
                final profile = b['profiles'];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage: profile?['avatar_url'] != null
                          ? NetworkImage(profile['avatar_url'])
                          : null,
                      child: profile?['avatar_url'] == null
                          ? const Icon(Icons.person, color: AppColors.primary)
                          : null,
                    ),
                    title: Text(profile?['full_name'] ?? 'Unknown'),
                    trailing: OutlinedButton(
                      onPressed: () => _unblock(b['blocked_id']),
                      child: const Text('Unblock'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
