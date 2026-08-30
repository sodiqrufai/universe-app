import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  final String? avatarUrl;
  final bool isGroup;
  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.avatarUrl,
    this.isGroup = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _hasError = false;
  String? _myUserId;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _showEmojiPicker = false;

  static const _emojis = [
    '😀', '😂', '😍', '🥲', '😭', '😡', '🙏', '👍', '👎', '❤️',
    '🔥', '🎉', '😴', '🤔', '😅', '😎', '🙄', '😢', '👏', '🥳',
    '🤝', '💯', '😬', '😱', '🤣', '😊', '🙌', '✅', '❌', '⚠️',
  ];

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchMessages(silent: true),
    );
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await _fetchMessages();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final data = await ApiService.get('/chat/${widget.conversationId}/messages');
      if (data['success'] == true) {
        final newMessages = data['messages'] ?? [];
        final shouldScroll = newMessages.length != _messages.length;
        setState(() {
          _messages = newMessages;
          _loading = false;
        });
        if (shouldScroll) _scrollToBottom();
      } else if (!silent) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (e) {
      // A silent background poll failing shouldn't flash an error screen
      // over an otherwise-working chat — only the initial load does.
      if (!silent) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? imagePath}) async {
    if (_messageController.text.trim().isEmpty && imagePath == null) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    // Multipart (for the optional image attachment) — ApiService has no
    // file-upload method, same legitimate exception as Course's resource
    // upload, still using the same token source as everywhere else.
    try {
      final token = await SessionService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/chat/${widget.conversationId}/messages'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      if (text.isNotEmpty) request.fields['content'] = text;
      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('attachment', imagePath));
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        await _fetchMessages();
      } else if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Message not sent')),
        );
      }
    } catch (_) {
      if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message not sent — check your connection')));
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      await _sendMessage(imagePath: picked.path);
    }
  }

  Future<void> _showOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                _report();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.error),
              title: const Text('Block user', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _block();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Report this conversation'),
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
        final data = await ApiService.post('/chat/report', {
          'conversationId': widget.conversationId,
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

  Future<void> _block() async {
    final otherId = _messages
        .map((m) => m['sender_id'])
        .firstWhere((id) => id != _myUserId, orElse: () => null);
    if (otherId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Block this user?'),
        content: const Text('They will no longer be able to message you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final data = await ApiService.post('/chat/block/$otherId', {});
        if (data['success'] == true && mounted) {
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not block this user')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not block this user')));
        }
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.lightPurple,
              backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
              child: widget.avatarUrl == null
                  ? Icon(widget.isGroup ? Icons.groups : Icons.person, size: 16, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: _showOptions),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.lightPurple,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 12, color: AppColors.primary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Messages are encrypted at rest. UniVerse staff may access chats when reviewing a safety report.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildMessages()),
          if (_showEmojiPicker) _buildEmojiGrid(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      color: AppColors.primary,
                    ),
                    onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                    onPressed: _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onTap: () {
                        if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                      },
                      decoration: const InputDecoration(hintText: 'Type a message...'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursor = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(cursor, cursor, emoji);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + emoji.length),
    );
  }

  Widget _buildEmojiGrid() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: _emojis.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => _insertEmoji(_emojis[i]),
          child: Center(child: Text(_emojis[i], style: const TextStyle(fontSize: 22))),
        ),
      ),
    );
  }

  void _openImageViewer(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 60,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load this conversation', onRetry: _fetchMessages);
    }
    if (_messages.isEmpty) {
      return const EmptyView(icon: Icons.waving_hand_outlined, title: 'Say hello 👋');
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        final isMine = m['sender_id'] == _myUserId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: isMine ? null : Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m['attachment_url'] != null)
                  GestureDetector(
                    onTap: () => _openImageViewer(m['attachment_url']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      child: Image.network(
                        m['attachment_url'],
                        width: 180,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                if (m['content'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      m['content'],
                      style: TextStyle(color: isMine ? Colors.white : AppColors.textPrimary),
                    ),
                  ),
                if (m['created_at'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('h:mm a').format(DateTime.parse(m['created_at']).toLocal()),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine ? Colors.white70 : AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
