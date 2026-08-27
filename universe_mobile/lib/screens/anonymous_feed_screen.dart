import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'anonymous_post_detail_screen.dart';

class AnonymousFeedScreen extends StatefulWidget {
  const AnonymousFeedScreen({super.key});

  @override
  State<AnonymousFeedScreen> createState() => _AnonymousFeedScreenState();
}

class _AnonymousFeedScreenState extends State<AnonymousFeedScreen> {
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
        Uri.parse('${ApiConfig.baseUrl}/anonymous/feed'),
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
              const Text('Share something anonymously', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  final token = await SessionService.getToken();
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/anonymous/posts'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode({'content': controller.text.trim(), 'category': category}),
                  );
                  final data = jsonDecode(response.body);
                  if (context.mounted) Navigator.of(context).pop(data['success'] == true);
                },
                child: const Text('Post'),
              ),
            ],
          ),
        ),
      ),
    );

    if (posted == true) _fetchFeed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anonymous')),
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
                            Center(child: Text('No posts yet — share something!')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final p = _posts[index];
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
                                            child: Text(p['category'], style: const TextStyle(fontSize: 10, color: AppColors.primary)),
                                          ),
                                          const Spacer(),
                                          Text('@$username', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(p['content'], style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showCreatePostSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}