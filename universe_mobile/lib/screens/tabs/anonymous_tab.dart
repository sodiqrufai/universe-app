import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/restricted_dialog.dart';
import '../anonymous_post_detail_screen.dart';
import '../anonymous_setup_screen.dart';

/// Anonymous: promoted from the old Community toggle to its own
/// standalone tab, unchanged in behavior — just no longer sharing a
/// screen (or a FAB) with the public feed.
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
                    if (data['success'] == true) {
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
    );

    if (posted == true) {
      _fetchFeed();
    }
    // Error messaging is now shown inline in the sheet's Post button
    // handler (so it can distinguish rate-limiting from other failures) —
    // no need for a second generic snackbar here.
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
            const Text('Could not load Anonymous'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _checkProfileAndFetch, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _checkProfileAndFetch,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          _buildSafeSpaceBanner(),
          const SizedBox(height: AppSpacing.md + 2),
          _buildCategoryFilter(),
          const SizedBox(height: AppSpacing.md),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
              side: const BorderSide(color: AppColors.border),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic p) {
    final username = p['anonymous_profiles']?['anonymous_username'] ?? 'anonymous';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AnonymousPostDetailScreen(post: p)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.lightPurple,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
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
