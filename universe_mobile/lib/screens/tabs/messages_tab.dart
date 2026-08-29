import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../chat_detail_screen.dart';

/// Messages as its own bottom-nav tab. Shares the shell's AppBar (no
/// AppBar of its own), unlike ChatInboxScreen which is still used when
/// a conversation is opened from elsewhere (e.g. "Message seller").
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
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
          _conversations = data['conversations'] ?? [];
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
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Could not load your messages'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchInbox, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchInbox,
        color: AppColors.primary,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No conversations yet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: Text(
                  'Messages from sellers, providers, and students you chat with will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchInbox,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _conversations.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 76, color: AppColors.border),
        itemBuilder: (context, index) {
          final c = _conversations[index];
          final isUnread = c['unread'] == true;
          final timeLabel = c['lastMessageAt'] != null
              ? DateFormat(
                  'MMM d',
                ).format(DateTime.parse(c['lastMessageAt']).toLocal())
              : '';

          return ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: c['avatarUrl'] != null
                  ? NetworkImage(c['avatarUrl'])
                  : null,
              child: c['avatarUrl'] == null
                  ? Icon(
                      c['isGroup'] == true ? Icons.groups : Icons.person,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            title: Text(
              c['name'] ?? 'Conversation',
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              c['lastMessage'] ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
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
    );
  }
}
