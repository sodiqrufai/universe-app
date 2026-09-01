import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/state_views.dart';
import '../create_post_screen.dart';
import '../post_detail_screen.dart';
import '../trending_screen.dart';
import 'story_carousel.dart';

/// Feed: the public campus feed, with announcements pinned above the
/// post list, a Trending pill row, and a story carousel (which itself
/// hosts the Notice Board entry point). Replaces the old HomeTab
/// dashboard — this is the landing tab now.
class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<dynamic> _posts = [];
  List<dynamic> _announcements = [];
  List<dynamic> _trending = [];
  String? _activeTag;
  bool _loading = true;
  bool _hasError = false;
  final _storyKey = GlobalKey<StoryCarouselState>();

  static const _tagColors = [
    AppColors.primary,
    AppColors.success,
    AppColors.warning,
    AppColors.info,
  ];

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
      final feedPath = _activeTag != null
          ? '/posts/feed?tag=${Uri.encodeQueryComponent(_activeTag!)}'
          : '/posts/feed';
      final results = await Future.wait([
        ApiService.get(feedPath),
        ApiService.get('/home'),
        ApiService.get('/posts/trending'),
      ]);
      final postsData = results[0];
      final homeData = results[1];
      final trendingData = results[2];
      if (postsData['success'] == true) {
        setState(() {
          _posts = postsData['posts'] ?? [];
          _announcements = homeData['announcements'] ?? [];
          _trending = trendingData['success'] == true ? (trendingData['trending'] ?? []) : [];
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

  void _selectTag(String? tag) {
    setState(() => _activeTag = _activeTag == tag ? null : tag);
    _fetchAll();
  }

  Future<void> _openTrendingScreen() async {
    final tag = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const TrendingScreen()));
    if (tag != null) _selectTag(tag);
  }

  Future<void> _toggleReaction(String postId, int index, String reactionType) async {
    final counts = Map<String, int>.from(_posts[index]['reactionCounts'] ?? {'like': 0, 'love': 0});
    final myReactions = List<String>.from(_posts[index]['myReactions'] ?? []);
    final wasReacted = myReactions.contains(reactionType);

    setState(() {
      if (wasReacted) {
        myReactions.remove(reactionType);
        counts[reactionType] = (counts[reactionType] ?? 1) - 1;
      } else {
        myReactions.add(reactionType);
        counts[reactionType] = (counts[reactionType] ?? 0) + 1;
      }
      _posts[index]['myReactions'] = myReactions;
      _posts[index]['reactionCounts'] = counts;
    });

    try {
      final data = await ApiService.post('/posts/$postId/react', {'reactionType': reactionType});
      if (data['success'] != true && mounted) {
        _revertReaction(index, reactionType, wasReacted);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not react to this post')));
      }
    } catch (_) {
      if (mounted) _revertReaction(index, reactionType, wasReacted);
    }
  }

  void _revertReaction(int index, String reactionType, bool wasReacted) {
    setState(() {
      final counts = Map<String, int>.from(_posts[index]['reactionCounts'] ?? {'like': 0, 'love': 0});
      final myReactions = List<String>.from(_posts[index]['myReactions'] ?? []);
      if (wasReacted) {
        myReactions.add(reactionType);
        counts[reactionType] = (counts[reactionType] ?? 0) + 1;
      } else {
        myReactions.remove(reactionType);
        counts[reactionType] = (counts[reactionType] ?? 1) - 1;
      }
      _posts[index]['myReactions'] = myReactions;
      _posts[index]['reactionCounts'] = counts;
    });
  }

  Future<void> _reshare(String postId) async {
    final data = await ApiService.post('/posts/$postId/reshare', {});
    if (!mounted) return;
    if (data['success'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reshared to your feed')));
      _fetchAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'] ?? 'Could not reshare this post')),
      );
    }
  }

  Future<void> _toggleSave(String postId, int index) async {
    final wasSaved = _posts[index]['isSaved'] == true;
    setState(() => _posts[index]['isSaved'] = !wasSaved);
    final data = await ApiService.post('/posts/$postId/save', {});
    if (data['success'] == true) {
      if (mounted) setState(() => _posts[index]['isSaved'] = data['saved'] == true);
    } else if (mounted) {
      setState(() => _posts[index]['isSaved'] = wasSaved);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not update saved posts')));
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
      return const LoadingView();
    }
    if (_hasError) {
      return ErrorView(message: 'Could not load the feed', onRetry: _fetchAll);
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
          if (_trending.isNotEmpty) ...[
            _buildTrendingRow(),
            const SizedBox(height: AppSpacing.md),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (_announcements.isNotEmpty) ...[
                  ..._announcements.map(_buildAnnouncementCard),
                  const SizedBox(height: 8),
                ],
                if (_activeTag != null) _buildActiveTagBanner(),
                if (_posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text(
                        _activeTag != null
                            ? 'No posts tagged "$_activeTag" yet'
                            : 'No posts yet — be the first to share something!',
                      ),
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

  Widget _buildTrendingRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trending on Campus',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
              GestureDetector(
                onTap: _openTrendingScreen,
                child: const Text(
                  'See all',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trending.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = _trending[i];
              final color = _tagColors[i % _tagColors.length];
              final selected = _activeTag == t['label'];
              return GestureDetector(
                onTap: () => _selectTag(t['label']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 14, color: selected ? Colors.white : color),
                      const SizedBox(width: 6),
                      Text(
                        t['label'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${t['count']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white70 : color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTagBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing posts tagged "$_activeTag"',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _selectTag(null),
            child: const Icon(Icons.close, size: 16, color: AppColors.primary),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (a['senderLabel'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          a['senderLabel'],
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
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
    final counts = post['reactionCounts'] ?? {'like': 0, 'love': 0};
    final myReactions = List<String>.from(post['myReactions'] ?? []);
    final iLiked = myReactions.contains('like');
    final iLoved = myReactions.contains('love');
    final isSaved = post['isSaved'] == true;

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
              if (post['tags'] != null && (post['tags'] as List).isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: (post['tags'] as List)
                      .map<Widget>(
                        (t) => GestureDetector(
                          onTap: () => _selectTag(t),
                          child: Text(
                            '#$t',
                            style: const TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (post['image_url'] != null) ...[
                const SizedBox(height: 10),
                AppNetworkImage(
                  post['image_url'],
                  width: double.infinity,
                  height: 180,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: iLiked ? 'Remove like' : 'Like this post',
                    child: GestureDetector(
                    onTap: () => _toggleReaction(post['id'], index, 'like'),
                    child: Row(
                      children: [
                        Icon(
                          iLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 17,
                          color: iLiked ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${counts['like'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Semantics(
                    button: true,
                    label: iLoved ? 'Remove love reaction' : 'Love this post',
                    child: GestureDetector(
                    onTap: () => _toggleReaction(post['id'], index, 'love'),
                    child: Row(
                      children: [
                        Icon(
                          iLoved ? Icons.favorite : Icons.favorite_border,
                          size: 17,
                          color: iLoved ? Colors.red : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${counts['love'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Semantics(
                    button: true,
                    label: 'Reshare this post',
                    child: GestureDetector(
                    onTap: () => _reshare(post['id']),
                    child: const Icon(Icons.repeat, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.mode_comment_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${post['commentCount'] ?? 0}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: isSaved ? 'Remove from saved posts' : 'Save post',
                    child: GestureDetector(
                    onTap: () => _toggleSave(post['id'], index),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: isSaved ? AppColors.primary : AppColors.textSecondary,
                    ),
                    ),
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
