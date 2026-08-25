// import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
// import '../services/session_service.dart';
import 'chat_detail_screen.dart';
import '../services/api_service.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  List<dynamic> _conversations = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchInbox();
  }

    Future<void> _fetchInbox() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/chat/inbox');
      if (data['success'] == true) {
        setState(() {
          _conversations = data['conversations'];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 40, color: Colors.black38),
                      const SizedBox(height: 12),
                      const Text('Could not load chats'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchInbox, child: const Text('Retry')),
                    ],
                  ),
                )
              : _conversations.isEmpty
                  ? const Center(child: Text('No conversations yet'))
                  : RefreshIndicator(
                      onRefresh: _fetchInbox,
                      color: AppColors.primary,
                      child: ListView.separated(
                        itemCount: _conversations.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = _conversations[index];
                          final timeLabel = c['lastMessageAt'] != null
                              ? DateFormat('MMM d, h:mm a').format(DateTime.parse(c['lastMessageAt']).toLocal())
                              : '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              backgroundImage: c['avatarUrl'] != null ? NetworkImage(c['avatarUrl']) : null,
                              child: c['avatarUrl'] == null
                                  ? Icon(c['isGroup'] == true ? Icons.groups : Icons.person, color: AppColors.primary)
                                  : null,
                            ),
                            title: Text(
                              c['name'] ?? 'Conversation',
                              style: TextStyle(fontWeight: c['unread'] == true ? FontWeight.bold : FontWeight.normal),
                            ),
                            subtitle: Text(
                              c['lastMessage'] ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: c['unread'] == true ? FontWeight.bold : FontWeight.normal),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(timeLabel, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                if (c['unread'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    conversationId: c['conversationId'],
                                    title: c['name'] ?? 'Conversation',
                                  ),
                                ),
                              );
                              _fetchInbox();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}