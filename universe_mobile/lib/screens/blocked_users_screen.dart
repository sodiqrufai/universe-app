import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blocked = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/profile/blocked-users');
      setState(() {
        _blocked = data['blocked'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _unblock(String blockedId) async {
    try {
      final data = await ApiService.delete('/chat/block/$blockedId');
      if (data['success'] == true) {
        _fetch();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not unblock this person')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unblock this person')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load blocked users', onRetry: _fetch);
    }
    if (_blocked.isEmpty) {
      return const EmptyView(
        icon: Icons.block,
        title: "You haven't blocked anyone",
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _blocked.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final b = _blocked[index];
          final profile = b['profiles'];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightPurple,
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
