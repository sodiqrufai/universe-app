import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/restricted_dialog.dart';
import '../../widgets/state_views.dart';
import '../../widgets/app_image.dart';
import '../../utils/relative_time.dart';
import '../anonymous_post_detail_screen.dart';
import '../anonymous_setup_screen.dart';

enum _SortMode { recent, trending }

class AnonymousTab extends StatefulWidget {
  const AnonymousTab({super.key});

  @override
  State<AnonymousTab> createState() => _AnonymousTabState();
}

class _AnonymousTabState extends State<AnonymousTab> {
  List<dynamic> _posts = [];
  bool _loading = true;
  bool _hasError = false;
  bool _hasProfile = false;
  String _category = 'all';
  _SortMode _sort = _SortMode.recent;

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
      final sortParam = _sort == _SortMode.trending ? '?sort=trending' : '';
      final data = await ApiService.get('/anonymous/feed$sortParam');
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

  void _changeSort(_SortMode mode) {
    if (_sort == mode) return;
    setState(() => _sort = mode);
    _fetchFeed();
  }

  List<dynamic> get _filteredPosts {
    if (_category == 'all') return _posts;
    return _posts.where((p) => p['category'] == _category).toList();
  }

  Future<void> _toggleReaction(String postId, int indexInPosts) async {
    final wasReacted = _posts[indexInPosts]['hasReacted'] == true;
    setState(() {
      _posts[indexInPosts]['hasReacted'] = !wasReacted;
      _posts[indexInPosts]['reactionCount'] =
          (_posts[indexInPosts]['reactionCount'] ?? 0) + (wasReacted ? -1 : 1);
    });
    try {
      final data = await ApiService.post('/anonymous/posts/$postId/react', {});
      if (data['success'] != true && mounted) {
        setState(() {
          _posts[indexInPosts]['hasReacted'] = wasReacted;
          _posts[indexInPosts]['reactionCount'] =
              (_posts[indexInPosts]['reactionCount'] ?? 0) + (wasReacted ? 1 : -1);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts[indexInPosts]['hasReacted'] = wasReacted;
          _posts[indexInPosts]['reactionCount'] =
              (_posts[indexInPosts]['reactionCount'] ?? 0) + (wasReacted ? 1 : -1);
        });
      }
    }
  }

  Future<void> _toggleSave(String postId, int indexInPosts) async {
    final wasSaved = _posts[indexInPosts]['isSaved'] == true;
    setState(() => _posts[indexInPosts]['isSaved'] = !wasSaved);
    try {
      final data = await ApiService.post('/anonymous/posts/$postId/save', {});
      if (data['success'] != true && mounted) {
        setState(() => _posts[indexInPosts]['isSaved'] = wasSaved);
      }
    } catch (_) {
      if (mounted) setState(() => _posts[indexInPosts]['isSaved'] = wasSaved);
    }
  }

  Future<void> _reshare(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Share this post?'),
        content: const Text('This shares it to Anonymous under your own anonymous identity.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Share')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final data = await ApiService.post('/anonymous/posts/$postId/reshare', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['success'] == true ? 'Shared' : (data['error'] ?? 'Could not share')),
          ),
        );
      }
      if (data['success'] == true) _fetchFeed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not share')));
      }
    }
  }

  Future<void> _votePoll(String pollId, int optionIndex, int indexInPosts) async {
    final poll = _posts[indexInPosts]['poll'];
    if (poll == null) return;
    final previousVote = poll['myVote'];
    // Optimistic: bump the new option, un-bump the old one if this is a
    // vote change rather than a first vote.
    setState(() {
      final counts = List<int>.from(poll['counts']);
      if (previousVote != null && previousVote != optionIndex) counts[previousVote]--;
      if (previousVote != optionIndex) counts[optionIndex]++;
      poll['counts'] = counts;
      poll['myVote'] = optionIndex;
    });
    try {
      final data = await ApiService.post('/anonymous/polls/$pollId/vote', {'optionIndex': optionIndex});
      if (data['success'] == true && mounted) {
        setState(() {
          poll['counts'] = data['counts'];
          poll['myVote'] = data['myVote'];
        });
      } else if (mounted) {
        setState(() {
          poll['myVote'] = previousVote;
        });
        _fetchFeed();
      }
    } catch (_) {
      if (mounted) _fetchFeed();
    }
  }

  Future<void> _createPost() async {
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
    bool addPoll = false;
    final questionController = TextEditingController();
    final optionControllers = [TextEditingController(), TextEditingController()];

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
          child: SingleChildScrollView(
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: addPoll,
                      onChanged: (v) => setModalState(() => addPoll = v ?? false),
                    ),
                    const Text('Add a poll'),
                  ],
                ),
                if (addPoll) ...[
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(hintText: 'Poll question'),
                  ),
                  const SizedBox(height: 8),
                  ...optionControllers.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(hintText: 'Option ${e.key + 1}'),
                      ),
                    ),
                  ),
                  if (optionControllers.length < 4)
                    TextButton.icon(
                      onPressed: () => setModalState(() => optionControllers.add(TextEditingController())),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add option'),
                    ),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    if (addPoll) {
                      final filledOptions =
                          optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                      if (questionController.text.trim().isEmpty || filledOptions.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('A poll needs a question and at least 2 options')),
                        );
                        return;
                      }
                    }
                    try {
                      final data = await ApiService.post('/anonymous/posts', {
                        'content': controller.text.trim(),
                        'category': category,
                      });
                      if (data['success'] == true) {
                        if (addPoll) {
                          final filledOptions = optionControllers
                              .map((c) => c.text.trim())
                              .where((t) => t.isNotEmpty)
                              .toList();
                          await ApiService.post('/anonymous/polls', {
                            'anonymousPostId': data['post']['id'],
                            'question': questionController.text.trim(),
                            'options': filledOptions,
                          });
                        }
                        if (context.mounted) Navigator.of(context).pop(true);
                      } else if (data['restricted'] == true) {
                        if (context.mounted) Navigator.of(context).pop(false);
                        if (mounted) {
                          await showRestrictedDialog(
                            this.context,
                            (data['error'] ?? 'This action is restricted on your account.').toString(),
                          );
                        }
                      } else {
                        final rawError = (data['error'] ?? '').toString();
                        final message = rawError.contains('ThrottlerException') ||
                                rawError.toLowerCase().contains('too many requests')
                            ? "You're posting a bit fast — wait a moment and try again."
                            : (rawError.isNotEmpty ? rawError : 'Could not post — try again');
                        if (mounted) {
                          ScaffoldMessenger.of(
                            this.context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                        if (context.mounted) Navigator.of(context).pop(false);
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
      ),
    );

    if (posted == true) {
      _fetchFeed();
    }
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
      return ErrorView(message: 'Could not load Anonymous', onRetry: _checkProfileAndFetch);
    }

    return RefreshIndicator(
      onRefresh: _checkProfileAndFetch,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          _buildSafeSpaceBanner(),
          const SizedBox(height: AppSpacing.md + 2),
          _buildSortTabs(),
          const SizedBox(height: AppSpacing.sm),
          _buildCategoryFilter(),
          const SizedBox(height: AppSpacing.md),
          if (_filteredPosts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: Text('No posts here yet — share something!')),
            )
          else
            ..._filteredPosts.asMap().entries.map(
              (e) => _buildPostCard(e.value, _posts.indexOf(e.value)),
            ),
        ],
      ),
    );
  }

  Widget _buildSafeSpaceBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
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
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your voice is safe here.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildSortTabs() {
    return Row(
      children: [
        Expanded(child: _sortTab('Recent', _SortMode.recent)),
        const SizedBox(width: 8),
        Expanded(child: _sortTab('Trending', _SortMode.trending)),
      ],
    );
  }

  Widget _sortTab(String label, _SortMode mode) {
    final selected = _sort == mode;
    return GestureDetector(
      onTap: () => _changeSort(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.lightPurple,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
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
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(color: AppColors.border),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic p, int indexInPosts) {
    final anonProfile = p['anonymous_profiles'];
    final username = anonProfile?['anonymous_username'] ?? 'anonymous';
    final avatarUrl = anonProfile?['avatar_url'];
    final hasReacted = p['hasReacted'] == true;
    final reactionCount = p['reactionCount'] ?? 0;
    final isSaved = p['isSaved'] == true;
    final poll = p['poll'];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AnonymousPostDetailScreen(post: p)),
          );
          _fetchFeed();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipOval(
                    child: avatarUrl != null
                        ? AppNetworkImage(avatarUrl, width: 28, height: 28, fit: BoxFit.cover)
                        : CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.lightPurple,
                            child: Icon(Icons.masks_outlined, size: 14, color: AppColors.primary),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '@$username',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\u00b7 ${formatRelativeTimeFromString(p['created_at'])}',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.lightPurple,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      p['category'] ?? '',
                      style: TextStyle(fontSize: 10, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(p['content'] ?? '', style: const TextStyle(fontSize: 14)),
              if (poll != null) ...[
                const SizedBox(height: 10),
                _buildPollCard(poll, indexInPosts),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleReaction(p['id'], indexInPosts),
                    child: Semantics(
                      label: hasReacted ? 'Unlike this post' : 'Like this post',
                      child: Row(
                        children: [
                          Icon(
                            hasReacted ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: hasReacted ? Colors.red : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text('$reactionCount', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AnonymousPostDetailScreen(post: p)),
                      );
                      _fetchFeed();
                    },
                    child: Semantics(
                      label: 'View comments',
                      child: Icon(Icons.mode_comment_outlined, size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () => _reshare(p['id']),
                    child: Semantics(
                      label: 'Share this post',
                      child: Icon(Icons.send_outlined, size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _toggleSave(p['id'], indexInPosts),
                    child: Semantics(
                      label: isSaved ? 'Remove from saved' : 'Save this post',
                      child: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
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

  Widget _buildPollCard(dynamic poll, int indexInPosts) {
    final counts = List<int>.from(poll['counts'] ?? []);
    final options = List<String>.from(poll['options'] ?? []);
    final total = counts.fold<int>(0, (a, b) => a + b);
    final myVote = poll['myVote'];
    final hasVoted = myVote != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(poll['question'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((e) {
            final i = e.key;
            final count = i < counts.length ? counts[i] : 0;
            final pct = total > 0 ? count / total : 0.0;
            final isMine = myVote == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => _votePoll(poll['id'], i, indexInPosts),
                child: Stack(
                  children: [
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        border: Border.all(color: isMine ? AppColors.primary : AppColors.border),
                      ),
                    ),
                    if (hasVoted)
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isMine ? FontWeight.w700 : FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasVoted)
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (total > 0)
            Text('$total vote${total == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
