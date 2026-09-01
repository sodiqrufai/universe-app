import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/state_views.dart';
import '../chat_detail_screen.dart';

enum _MsgFilter { all, groups, unread }

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
  _MsgFilter _filter = _MsgFilter.all;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchInbox();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<dynamic> get _filtered {
    var list = _conversations;
    if (_filter == _MsgFilter.groups) {
      list = list.where((c) => c['isGroup'] == true).toList();
    } else if (_filter == _MsgFilter.unread) {
      list = list.where((c) => c['unread'] == true).toList();
    }
    if (_query.isNotEmpty) {
      list = list
          .where((c) => (c['name'] ?? '').toString().toLowerCase().contains(_query))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingView();
    }
    if (_hasError) {
      return ErrorView(message: 'Could not load your messages', onRetry: _fetchInbox);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear search',
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip('All', _MsgFilter.all),
              const SizedBox(width: 8),
              _filterChip('Groups', _MsgFilter.groups),
              const SizedBox(width: 8),
              _filterChip('Unread', _MsgFilter.unread),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _filterChip(String label, _MsgFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.lightPurple,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildList() {
    final list = _filtered;

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

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchInbox,
        color: AppColors.primary,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No conversations match this filter')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchInbox,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: list.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 76, color: AppColors.border),
        itemBuilder: (context, index) {
          final c = list[index];
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
                    avatarUrl: c['avatarUrl'],
                    isGroup: c['isGroup'] == true,
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
