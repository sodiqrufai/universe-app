import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AnonymousPostDetailScreen extends StatefulWidget {
  final dynamic post;
  const AnonymousPostDetailScreen({super.key, required this.post});

  @override
  State<AnonymousPostDetailScreen> createState() =>
      _AnonymousPostDetailScreenState();
}

class _AnonymousPostDetailScreenState extends State<AnonymousPostDetailScreen> {
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
      // Backend now returns a ready-built two-level tree here too — same
      // contract as posts.controller.ts's comments endpoint.
      final data = await ApiService.get(
        '/anonymous/posts/${widget.post['id']}/comments',
      );
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
      final parentId = _replyingTo?['parent_comment_id'] ?? _replyingTo?['id'];
      final data = await ApiService.post(
        '/anonymous/posts/${widget.post['id']}/comments',
        {
          'content': _commentController.text.trim(),
          'parentCommentId': ?parentId,
        },
      );
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

  Future<void> _toggleCommentReaction(dynamic comment) async {
    final wasReacted = comment['hasReacted'] == true;
    setState(() {
      comment['hasReacted'] = !wasReacted;
      comment['reactionCount'] = (comment['reactionCount'] ?? 0) + (wasReacted ? -1 : 1);
    });
    try {
      final data = await ApiService.post('/anonymous/comments/${comment['id']}/react', {});
      if (data['success'] != true && mounted) {
        setState(() {
          comment['hasReacted'] = wasReacted;
          comment['reactionCount'] = (comment['reactionCount'] ?? 0) + (wasReacted ? 1 : -1);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          comment['hasReacted'] = wasReacted;
          comment['reactionCount'] = (comment['reactionCount'] ?? 0) + (wasReacted ? 1 : -1);
        });
      }
    }
  }

  Future<void> _report() async {
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
          decoration: const InputDecoration(hintText: 'Reason'),
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
        final data = await ApiService.post(
          '/anonymous/posts/${widget.post['id']}/report',
          {'reason': reason},
        );
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

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username =
        widget.post['anonymous_profiles']?['anonymous_username'] ?? 'anonymous';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Post'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report post',
            onPressed: _report,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  '@$username',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(widget.post['content'], style: const TextStyle(fontSize: 15)),
                const Divider(height: 32),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              'Replying to @${_replyingTo['anonymous_profiles']?['anonymous_username'] ?? 'anonymous'}',
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
                            hintText: _replyingTo != null ? 'Reply anonymously...' : 'Reply anonymously...',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _sending ? null : _sendComment,
                        tooltip: 'Send reply',
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
          const Text('Could not load comments', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _fetchComments, child: const Text('Retry')),
        ],
      );
    }
    if (_comments.isEmpty) {
      return const Text('No comments yet.', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      children: _comments.map((c) => _buildCommentThread(c)).toList(),
    );
  }

  Widget _buildCommentThread(dynamic comment) {
    final replies = (comment['replies'] as List<dynamic>?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentRow(comment, isReply: false),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Container(
                padding: const EdgeInsets.only(left: 14),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.border, width: 2)),
                ),
                child: Column(
                  children: replies
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(top: 10),
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
    final cUsername = c['anonymous_profiles']?['anonymous_username'] ?? 'anonymous';
    final hasReacted = c['hasReacted'] == true;
    final reactionCount = c['reactionCount'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '@$cUsername',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Text(c['content'], style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          children: [
            Semantics(
              button: true,
              label: hasReacted ? 'Remove like from comment' : 'Like comment',
              child: GestureDetector(
                onTap: () => _toggleCommentReaction(c),
                child: Row(
                  children: [
                    Icon(
                      hasReacted ? Icons.favorite : Icons.favorite_border,
                      size: 13,
                      color: hasReacted ? Colors.red : AppColors.textMuted,
                    ),
                    if (reactionCount > 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        '$reactionCount',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _startReply(c),
              child: const Text(
                'Reply',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
