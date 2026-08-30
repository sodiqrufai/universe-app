import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import 'post_detail_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  List<dynamic> _posts = [];
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
      final data = await ApiService.get('/profile/my-posts');
      setState(() {
        _posts = data['posts'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Posts')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load your posts', onRetry: _fetch);
    }
    if (_posts.isEmpty) {
      return const EmptyView(
        icon: Icons.article_outlined,
        title: "You haven't posted anything yet",
        subtitle: 'Posts you share will show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = _posts[index];
          final isRemoved = p['is_removed'] == true;
          return Card(
            color: isRemoved ? AppColors.lightPurple.withValues(alpha: 0.4) : null,
            child: ListTile(
              leading: isRemoved
                  ? const Icon(Icons.block, color: AppColors.error)
                  : null,
              title: Text(
                p['content'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isRemoved
                    ? const TextStyle(color: AppColors.textMuted, decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: isRemoved
                  ? Text(
                      'Removed by a moderator${p['removed_reason'] != null ? ': ${p['removed_reason']}' : ''}',
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    )
                  : Text('${p['reactionCounts']?['like'] ?? 0} likes, ${p['reactionCounts']?['love'] ?? 0} loves'),
              onTap: isRemoved
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PostDetailScreen(post: p)),
                      );
                      _fetch();
                    },
            ),
          );
        },
      ),
    );
  }
}
