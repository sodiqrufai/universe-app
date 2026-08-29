import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../create_post_screen.dart';
import '../post_detail_screen.dart';
import '../anonymous_post_detail_screen.dart';
import '../anonymous_setup_screen.dart';

/// The Community tab: one entry point that hosts both the public Campus
/// Feed and the Anonymous Confessions space behind a top toggle, so
/// students land in one rich "environment" instead of two separate tabs.
class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  int _mode = 0; // 0 = Public, 1 = Anonymous

  final _publicKey = GlobalKey<_PublicFeedState>();
  final _anonKey = GlobalKey<_AnonymousFeedState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildToggle(),
          ),
          Expanded(
            child: IndexedStack(
              index: _mode,
              children: [
                _PublicFeed(key: _publicKey),
                _AnonymousFeed(key: _anonKey),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          if (_mode == 0) {
            _publicKey.currentState?.createPost();
          } else {
            _anonKey.currentState?.createPost();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
              label: 'Public Feed',
              icon: Icons.forum_outlined,
              selected: _mode == 0,
              onTap: () => setState(() => _mode = 0),
            ),
          ),
          Expanded(
            child: _toggleButton(
              label: 'Anonymous',
              icon: Icons.masks_outlined,
              selected: _mode == 1,
              onTap: () => setState(() => _mode = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Public feed (existing Campus Feed behavior, ported onto ApiService)
// ---------------------------------------------------------------------

class _PublicFeed extends StatefulWidget {
  const _PublicFeed({super.key});

  @override
  State<_PublicFeed> createState() => _PublicFeedState();
}

class _PublicFeedState extends State<_PublicFeed> {
  List<dynamic> _posts = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/posts/feed');
      if (data['success'] == true) {
        setState(() {
          _posts = data['posts'] ?? [];
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
        // revert on failure and tell the user, per lesson #5 (no silent failures)
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

  Future<void> createPost() async {
    final created = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
    if (created == true) _fetchFeed();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
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
            ElevatedButton(onPressed: _fetchFeed, child: const Text('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchFeed,
      color: AppColors.primary,
      child: _posts.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 100),
                Center(
                  child: Text('No posts yet — be the first to share something!'),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              itemCount: _posts.length,
              itemBuilder: (context, index) => _buildPostCard(_posts[index], index),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
          );
          _fetchFeed();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
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
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Global',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(post['content'] ?? '', style: const TextStyle(fontSize: 14)),
              if (post['image_url'] != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                          post['hasReacted'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
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

// ---------------------------------------------------------------------
// Anonymous feed (existing Anonymous behavior, ported + inlined)
// ---------------------------------------------------------------------

class _AnonymousFeed extends StatefulWidget {
  const _AnonymousFeed({super.key});

  @override
  State<_AnonymousFeed> createState() => _AnonymousFeedState();
}

class _AnonymousFeedState extends State<_AnonymousFeed> {
  List<dynamic> _posts = [];
  bool _loading = true;
  bool _hasError = false;
  bool _hasProfile = false;
  String _category = 'all';

  final _categories = const ['all', 'rant', 'advice', 'confession', 'talk'];

  @override
  void initState() {
    super.initState();
    _checkProfileAndFetch();
  }

  Future<void> _checkProfileAndFetch() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final profileData = await ApiService.get('/anonymous/profile');
      _hasProfile = profileData['success'] == true && profileData['profile'] != null;
      await _fetchFeed();
    } catch (e) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _fetchFeed() async {
    try {
      final data = await ApiService.get('/anonymous/feed');
      if (data['success'] == true) {
        setState(() {
          _posts = data['posts'] ?? [];
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

  List<dynamic> get _filteredPosts {
    if (_category == 'all') return _posts;
    return _posts.where((p) => p['category'] == _category).toList();
  }

  Future<void> createPost() async {
    if (!_hasProfile) {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AnonymousSetupScreen()),
      );
      if (done == true) {
        setState(() => _hasProfile = true);
      } else {
        return;
      }
    }
    await _showCreatePostSheet();
  }

  Future<void> _showCreatePostSheet() async {
    final controller = TextEditingController();
    String category = 'talk';

    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Share something anonymously',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['rant', 'advice', 'confession', 'talk'].map((c) {
                  return ChoiceChip(
                    label: Text(c),
                    selected: category == c,
                    onSelected: (_) => setModalState(() => category = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(hintText: "What's on your mind?"),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  try {
                    final data = await ApiService.post('/anonymous/posts', {
                      'content': controller.text.trim(),
                      'category': category,
                    });
                    if (context.mounted) {
                      Navigator.of(context).pop(data['success'] == true);
                    }
                  } catch (_) {
                    if (context.mounted) Navigator.of(context).pop(false);
                  }
                },
                child: const Text('Post'),
              ),
            ],
          ),
        ),
      ),
    );

    if (posted == true) {
      _fetchFeed();
    } else if (posted == false && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not post — try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Could not load Anonymous'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _checkProfileAndFetch,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _checkProfileAndFetch,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        children: [
          _buildSafeSpaceBanner(),
          const SizedBox(height: 14),
          _buildCategoryFilter(),
          const SizedBox(height: 12),
          if (_filteredPosts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: Text('No posts here yet — share something!')),
            )
          else
            ..._filteredPosts.map(_buildPostCard),
        ],
      ),
    );
  }

  Widget _buildSafeSpaceBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.masks_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your voice is safe here.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '100% anonymous, always.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _categories[i];
          final selected = _category == c;
          return ChoiceChip(
            label: Text(c[0].toUpperCase() + c.substring(1)),
            selected: selected,
            onSelected: (_) => setState(() => _category = c),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic p) {
    final username = p['anonymous_profiles']?['anonymous_username'] ?? 'anonymous';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AnonymousPostDetailScreen(post: p)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p['category'] ?? '',
                      style: const TextStyle(fontSize: 10, color: AppColors.primary),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '@$username',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(p['content'] ?? '', style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
