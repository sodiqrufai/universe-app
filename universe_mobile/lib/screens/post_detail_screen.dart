import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
  bool _hasError = false;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _sending = false;
  dynamic _replyingTo;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/posts/${widget.post['id']}/comments');
      setState(() {
        _comments = data['comments'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      // Top-level replies always thread under the top-level ancestor,
      // not the specific comment tapped — keeps nesting to one visual
      // level instead of unbounded indentation, while still recording
      // exactly who's being replied to via the visible "Replying to" tag.
      final parentId = _replyingTo?['parent_comment_id'] ?? _replyingTo?['id'];
      final data = await ApiService.post('/posts/${widget.post['id']}/comments', {
        'content': _commentController.text.trim(),
        if (parentId != null) 'parentCommentId': parentId,
      });
      if (data['success'] == true) {
        _commentController.clear();
        setState(() => _replyingTo = null);
        _fetchComments();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not post comment')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not post comment')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startReply(dynamic comment) {
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  Future<void> _messageAuthor() async {
    final authorId = widget.post['author_id'];
    if (authorId == null) return;
    try {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not start conversation')));
      }
    }
  }

  Future<void> _reportPost() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Report this post'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Why are you reporting this?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      try {
        final data = await ApiService.post('/posts/${widget.post['id']}/report', {
          'reason': reason,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['success'] == true ? 'Report submitted' : (data['error'] ?? 'Could not submit report'),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not submit report')));
        }
      }
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete this post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final data = await ApiService.delete('/posts/${widget.post['id']}');
        if (data['success'] == true && mounted) {
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not delete post')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not delete post')));
        }
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'];
    final name = profile?['full_name'] ?? 'Student';
    final avatarUrl = profile?['avatar_url'];

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
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                      child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: _messageAuthor,
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Message'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(widget.post['content'], style: const TextStyle(fontSize: 15)),
                if (widget.post['image_url'] != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    child: Image.network(
                      widget.post['image_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 200,
                          color: AppColors.lightPurple,
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => Container(
                        height: 200,
                        color: AppColors.lightPurple,
                        child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
                const Divider(height: 32),
                const Text(
                  'Comments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildComments(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to ${_replyingTo['profiles']?['full_name'] ?? 'comment'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _replyingTo = null),
                            child: const Icon(Icons.close, size: 16, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          decoration: InputDecoration(
                            hintText: _replyingTo != null ? 'Write a reply...' : 'Write a comment...',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _sending ? null : _sendComment,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.send, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComments() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_hasError) {
      return Column(
        children: [
          const Text(
            'Could not load comments',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _fetchComments, child: const Text('Retry')),
        ],
      );
    }
    if (_comments.isEmpty) {
      return const Text(
        'No comments yet — be the first to reply.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    final topLevel = _comments.where((c) => c['parent_comment_id'] == null).toList();
    final repliesByParent = <String, List<dynamic>>{};
    for (final c in _comments) {
      final parentId = c['parent_comment_id'];
      if (parentId != null) {
        repliesByParent.putIfAbsent(parentId, () => []).add(c);
      }
    }

    return Column(
      children: topLevel.map((c) => _buildCommentThread(c, repliesByParent[c['id']] ?? [])).toList(),
    );
  }

  Widget _buildCommentThread(dynamic comment, List<dynamic> replies) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentRow(comment, isReply: false),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 8),
              child: Container(
                padding: const EdgeInsets.only(left: 14),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.border, width: 2)),
                ),
                child: Column(
                  children: replies
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildCommentRow(r, isReply: true),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentRow(dynamic c, {required bool isReply}) {
    final cProfile = c['profiles'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 12 : 14,
          backgroundColor: AppColors.lightPurple,
          backgroundImage: cProfile?['avatar_url'] != null
              ? NetworkImage(cProfile['avatar_url'])
              : null,
          child: cProfile?['avatar_url'] == null
              ? Icon(Icons.person, size: isReply ? 12 : 14, color: AppColors.primary)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cProfile?['full_name'] ?? 'Student',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(c['content'], style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _startReply(c),
                child: const Text(
                  'Reply',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
