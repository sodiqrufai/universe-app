import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import 'chat_detail_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final dynamic post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<dynamic> _comments = [];
  bool _loading = true;
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/posts/${widget.post['id']}/comments'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _comments = data['comments'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
    });
    final token = await SessionService.getToken();
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/posts/${widget.post['id']}/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': _commentController.text.trim()}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _commentController.clear();
        _fetchComments();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _messageAuthor() async {
    final authorId = widget.post['author_id'];
    if (authorId == null) return;

    final data = await ApiService.post('/chat/direct', {'otherUserId': authorId});
    if (data['success'] == true && mounted) {
      final profile = widget.post['profiles'];
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: data['conversationId'],
            title: profile?['full_name'] ?? 'Chat',
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'] ?? 'Could not start conversation')),
      );
    }
  }

  Future<void> _reportPost() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report this post'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Why are you reporting this?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      final token = await SessionService.getToken();
      await http.post(
        Uri.parse('http://localhost:3000/posts/${widget.post['id']}/report'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted')),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final token = await SessionService.getToken();
      await http.delete(
        Uri.parse('http://localhost:3000/posts/${widget.post['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'];
    final name = profile?['full_name'] ?? 'Student';
    final avatarUrl = profile?['avatar_url'];
    final myUserId = null; // ownership check simplified: server enforces real permission

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _reportPost();
              if (value == 'delete') _deletePost();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report', child: Text('Report')),
              const PopupMenuItem(value: 'delete', child: Text('Delete (if yours)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person, size: 18, color: AppColors.primary) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    TextButton.icon(
                      onPressed: _messageAuthor,
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Message'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(widget.post['content'], style: const TextStyle(fontSize: 15)),
                if (widget.post['image_url'] != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(widget.post['image_url'], fit: BoxFit.cover, width: double.infinity),
                  ),
                ],
                const Divider(height: 32),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: AppColors.primary))
                else if (_comments.isEmpty)
                  const Text('No comments yet — be the first to reply.', style: TextStyle(color: Colors.black54))
                else
                  ..._comments.map((c) {
                    final cProfile = c['profiles'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: cProfile?['avatar_url'] != null ? NetworkImage(cProfile['avatar_url']) : null,
                            child: cProfile?['avatar_url'] == null
                                ? const Icon(Icons.person, size: 14, color: AppColors.primary)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cProfile?['full_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(c['content'], style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(hintText: 'Write a comment...'),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _sendComment,
                    icon: const Icon(Icons.send, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}