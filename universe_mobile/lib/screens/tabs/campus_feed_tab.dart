import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/session_service.dart';
import '../create_post_screen.dart';
import '../post_detail_screen.dart';
// import '../chat_inbox_screen.dart';

class CampusFeedTab extends StatefulWidget {
  const CampusFeedTab({super.key});

  @override
  State<CampusFeedTab> createState() => _CampusFeedTabState();
}

class _CampusFeedTabState extends State<CampusFeedTab> {
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
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/posts/feed'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _posts = data['posts'];
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
    final token = await SessionService.getToken();
    setState(() {
      final wasReacted = _posts[index]['hasReacted'] == true;
      _posts[index]['hasReacted'] = !wasReacted;
      _posts[index]['reactionCount'] = (_posts[index]['reactionCount'] ?? 0) + (wasReacted ? -1 : 1);
    });
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/posts/$postId/react'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 40, color: Colors.black38),
                      const SizedBox(height: 12),
                      const Text('Could not load the feed'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchFeed, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchFeed,
                  color: AppColors.primary,
                  child: _posts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No posts yet — be the first to share something!')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) => _buildPostCard(_posts[index], index),
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final created = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          if (created == true) _fetchFeed();
        },
        child: const Icon(Icons.add, color: Colors.white),
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
                          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
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
                      child: const Text('Global', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(post['content'], style: const TextStyle(fontSize: 14)),
              if (post['image_url'] != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(post['image_url'], fit: BoxFit.cover, width: double.infinity, height: 180),
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
                          color: post['hasReacted'] == true ? Colors.red : Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text('${post['reactionCount'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.mode_comment_outlined, size: 18, color: Colors.black45),
                  const SizedBox(width: 4),
                  Text('${post['commentCount'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}