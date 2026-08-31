import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import 'listing_detail_screen.dart';
import 'post_detail_screen.dart';

class SavedListingsScreen extends StatefulWidget {
  const SavedListingsScreen({super.key});

  @override
  State<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends State<SavedListingsScreen> {
  List<dynamic> _listings = [];
  List<dynamic> _posts = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchSaved();
  }

  Future<void> _fetchSaved() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        ApiService.get('/marketplace/saved'),
        ApiService.get('/posts/saved'),
      ]);
      setState(() {
        _listings = results[0]['listings'] ?? [];
        _posts = results[1]['posts'] ?? [];
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Items'), Tab(text: 'Posts')],
          ),
        ),
        body: _loading
            ? const LoadingView()
            : _hasError
                ? ErrorView(message: 'Could not load your saved content', onRetry: _fetchSaved)
                : TabBarView(
                    children: [_buildListings(), _buildPosts()],
                  ),
      ),
    );
  }

  Widget _buildListings() {
    if (_listings.isEmpty) {
      return const EmptyView(
        icon: Icons.bookmark_border,
        title: 'No saved items yet',
        subtitle: 'Listings you save will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchSaved,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _listings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final l = _listings[index];
          final images = l['listing_images'] as List<dynamic>? ?? [];
          final imageUrl = images.isNotEmpty ? images.first['image_url'] : null;
          return Card(
            child: ListTile(
              leading: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : const Icon(Icons.image_outlined, color: AppColors.primary),
              title: Text(l['title']),
              subtitle: Text('₦${l['price']}'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listingId: l['id']),
                  ),
                );
                _fetchSaved();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPosts() {
    if (_posts.isEmpty) {
      return const EmptyView(
        icon: Icons.bookmark_border,
        title: 'No saved posts yet',
        subtitle: 'Posts you save will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchSaved,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = _posts[index];
          final profile = p['profiles'];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.lightPurple,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              title: Text(profile?['full_name'] ?? 'Student'),
              subtitle: Text(
                p['content'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PostDetailScreen(post: p)),
                );
                _fetchSaved();
              },
            ),
          );
        },
      ),
    );
  }
}
