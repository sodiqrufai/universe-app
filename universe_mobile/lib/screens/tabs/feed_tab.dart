import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../create_post_screen.dart';
import '../post_detail_screen.dart';
import 'story_carousel.dart';

/// Feed: the public campus feed, with announcements pinned above the
/// post list. Replaces the old HomeTab dashboard — this is the landing
/// tab now, so it leads with real content instead of a shortcuts grid.
class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<dynamic> _posts = [];
  List<dynamic> _announcements = [];
  bool _loading = true;
  bool _hasError = false;
  final _storyKey = GlobalKey<StoryCarouselState>();

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        ApiService.get('/posts/feed'),
        ApiService.get('/home'),
      ]);
      final postsData = results[0];
      final homeData = results[1];
      if (postsData['success'] == true) {
        setState(() {
          _posts = postsData['posts'] ?? [];
          _announcements = homeData['announcements'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _toggleReaction(String postId, int index) async {
    final wasReacted = _posts[index]['hasReacted'] == true;
    setState(() {
      _posts[index]['hasReacted'] = !wasReacted;
      _posts[index]['reactionCount'] =
          (_posts[index]['reactionCount'] ?? 0) + (wasReacted ? -1 : 1);
    });
    try {
      final data = await ApiService.post('/posts/$postId/react', {});
      if (data['success'] != true && mounted) {
        setState(() {
          _posts[index]['hasReacted'] = wasReacted;
          _posts[index]['reactionCount'] =
              (_posts[index]['reactionCount'] ?? 0) + (wasReacted ? 1 : -1);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not react to this post')));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts[index]['hasReacted'] = wasReacted;
          _posts[index]['reactionCount'] =
              (_posts[index]['reactionCount'] ?? 0) + (wasReacted ? 1 : -1);
        });
      }
    }
  }

  Future<void> _createPost() async {
    final created = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
    if (created == true) _fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _createPost,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Could not load the feed'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchAll, child: const Text('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _fetchAll(),
          _storyKey.currentState?.refresh() ?? Future.value(),
        ]);
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 90),
        children: [
          StoryCarousel(key: _storyKey),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (_announcements.isNotEmpty) ...[
                  ..._announcements.map(_buildAnnouncementCard),
                  const SizedBox(height: 8),
                ],
                if (_posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text('No posts yet — be the first to share something!'),
                    ),
                  )
                else
                  ..._posts.asMap().entries.map((e) => _buildPostCard(e.value, e.key)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(dynamic a) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  a['body'] ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(dynamic post, int index) {
    final profile = post['profiles'];
    final name = profile?['full_name'] ?? 'Student';
    final isVerified = profile?['is_verified'] == true;
    final avatarUrl = profile?['avatar_url'];
    final isGlobal = post['visibility'] == 'global';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
          );
          _fetchAll();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.lightPurple,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 18, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                  if (isGlobal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Text(
                        'Global',
                        style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(post['content'] ?? '', style: const TextStyle(fontSize: 14)),
              if (post['image_url'] != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: Image.network(
                    post['image_url'],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleReaction(post['id'], index),
                    child: Row(
                      children: [
                        Icon(
                          post['hasReacted'] == true ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: post['hasReacted'] == true ? Colors.red : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post['reactionCount'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.mode_comment_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${post['commentCount'] ?? 0}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
