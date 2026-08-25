import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  const ChatDetailScreen({super.key, required this.conversationId, required this.title});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  List<dynamic> _messages = [];
  bool _loading = true;
  String? _myUserId;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages(silent: true));
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await _fetchMessages();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
      });
    }
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/chat/${widget.conversationId}/messages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final newMessages = data['messages'] ?? [];
        final shouldScroll = newMessages.length != _messages.length;
        setState(() {
          _messages = newMessages;
          _loading = false;
        });
        if (shouldScroll) _scrollToBottom();
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
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

    final token = await SessionService.getToken();
    final text = _messageController.text.trim();
    _messageController.clear();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:3000/chat/${widget.conversationId}/messages'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      if (text.isNotEmpty) request.fields['content'] = text;
      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('attachment', imagePath));
      }
      await request.send();
      await _fetchMessages();
    } catch (_) {}
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
      builder: (context) => Column(
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
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text('Block user', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _block();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report this conversation'),
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
        Uri.parse('http://localhost:3000/chat/report'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'conversationId': widget.conversationId, 'reason': reason}),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
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
        title: const Text('Block this user?'),
        content: const Text('They will no longer be able to message you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
        ],
      ),
    );
    if (confirm == true) {
      final token = await SessionService.getToken();
      await http.post(
        Uri.parse('http://localhost:3000/chat/block/$otherId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted) Navigator.of(context).pop();
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
        title: Text(widget.title),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: _showOptions)],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? const Center(child: Text('Say hello 👋'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
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
                                color: isMine ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m['attachment_url'] != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(m['attachment_url'], width: 180),
                                    ),
                                  if (m['content'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        m['content'],
                                        style: TextStyle(color: isMine ? Colors.white : AppColors.textPrimary),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image_outlined, color: AppColors.primary), onPressed: _pickAndSendImage),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
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
}