import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'chat_detail_screen.dart';
import 'listing_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await ApiService.get('/notifications');
      setState(() {
        _notifications = data['notifications'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.patch('/notifications/read-all', {});
    _fetch();
  }

  Future<void> _handleTap(dynamic n) async {
    await ApiService.patch('/notifications/${n['id']}/read', {});
    final data = n['data'];
    if (n['type'] == 'chat_message' &&
        data != null &&
        data['conversationId'] != null) {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              conversationId: data['conversationId'],
              title: n['title'],
            ),
          ),
        );
      }
    } else if (n['type'] == 'new_offer' &&
        data != null &&
        data['listingId'] != null) {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listingId: data['listingId']),
          ),
        );
      }
    }
    _fetch();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'verification_approved':
        return Icons.verified_outlined;
      case 'verification_rejected':
        return Icons.error_outline;
      case 'new_offer':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _notifications.isEmpty
          ? const Center(child: Text('No notifications yet'))
          : RefreshIndicator(
              onRefresh: _fetch,
              color: AppColors.primary,
              child: ListView.separated(
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  final timeLabel = DateFormat(
                    'MMM d, h:mm a',
                  ).format(DateTime.parse(n['created_at']).toLocal());
                  final isUnread = n['is_read'] != true;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        _iconFor(n['type']),
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      n['title'],
                      style: TextStyle(
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      n['body'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _handleTap(n),
                  );
                },
              ),
            ),
    );
  }
}
