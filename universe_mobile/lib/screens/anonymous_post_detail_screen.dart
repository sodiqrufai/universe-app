import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';

class AnonymousPostDetailScreen extends StatefulWidget {
  final dynamic post;
  const AnonymousPostDetailScreen({super.key, required this.post});

  @override
  State<AnonymousPostDetailScreen> createState() => _AnonymousPostDetailScreenState();
}

class _AnonymousPostDetailScreenState extends State<AnonymousPostDetailScreen> {
  List<dynamic> _comments = [];
  bool _loading = true;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/anonymous/posts/${widget.post['id']}/comments'),
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
    final token = await SessionService.getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/anonymous/posts/${widget.post['id']}/comments'),
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
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report this post'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, reasonController.text.trim()), child: const Text('Report')),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      final token = await SessionService.getToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/anonymous/posts/${widget.post['id']}/report'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'reason': reason}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.post['anonymous_profiles']?['anonymous_username'] ?? 'anonymous';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Post'),
        actions: [IconButton(icon: const Icon(Icons.flag_outlined), onPressed: _report)],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('@$username', style: const TextStyle(color: Colors.black45, fontSize: 13)),
                const SizedBox(height: 8),
                Text(widget.post['content'], style: const TextStyle(fontSize: 15)),
                const Divider(height: 32),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: AppColors.primary))
                else if (_comments.isEmpty)
                  const Text('No comments yet.', style: TextStyle(color: Colors.black54))
                else
                  ..._comments.map((c) {
                    final cUsername = c['anonymous_profiles']?['anonymous_username'] ?? 'anonymous';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@$cUsername', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                          Text(c['content'], style: const TextStyle(fontSize: 13)),
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
                      decoration: const InputDecoration(hintText: 'Reply anonymously...'),
                    ),
                  ),
                  IconButton(onPressed: _sendComment, icon: const Icon(Icons.send, color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}