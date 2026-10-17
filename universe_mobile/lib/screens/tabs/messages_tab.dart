import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/state_views.dart';
import 'explore_tab.dart';
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
  String _errorMessage = 'Could not load your messages';
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
          _errorMessage = loadErrorMessage(data, 'Could not load your messages');
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
      return ErrorView(message: _errorMessage, onRetry: _fetchInbox);
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

  void _openExplore() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Explore')),
          body: const ExploreTab(),
        ),
      ),
    );
  }

  /// Shown when there ARE conversations but the search or filter hides them
  /// all, so the message says why and offers the way back.
  Widget _buildNoMatchState() {
    if (_query.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: 'No matches for "${_searchController.text.trim()}"',
        message: 'Check the spelling or try a different name.',
        actionLabel: 'Clear search',
        actionIcon: Icons.close,
        onAction: _searchController.clear,
      );
    }
    switch (_filter) {
      case _MsgFilter.groups:
        return AppEmptyState(
          icon: Icons.groups_outlined,
          title: 'No group chats yet',
          message: 'Group conversations will show up here.',
          actionLabel: 'Show all messages',
          actionIcon: Icons.chat_bubble_outline,
          onAction: () => setState(() => _filter = _MsgFilter.all),
        );
      case _MsgFilter.unread:
        return AppEmptyState(
          icon: Icons.mark_chat_read_outlined,
          title: "You're all caught up",
          message: 'No unread messages right now.',
          actionLabel: 'Show all messages',
          actionIcon: Icons.chat_bubble_outline,
          onAction: () => setState(() => _filter = _MsgFilter.all),
        );
      case _MsgFilter.all:
        return const AppEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'No conversations here',
          message: 'Pull down to refresh.',
        );
    }
  }

  Widget _buildList() {
    final list = _filtered;

    if (_conversations.isEmpty) {
      return RefreshableEmptyState(
        onRefresh: _fetchInbox,
        child: AppEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'No messages yet',
          message:
              'Chats with sellers, service providers and classmates will show up here. Find something you like in Explore and say hello.',
          actionLabel: 'Browse Explore',
          actionIcon: Icons.explore_outlined,
          onAction: _openExplore,
        ),
      );
    }

    if (list.isEmpty) {
      return RefreshableEmptyState(
        onRefresh: _fetchInbox,
        child: _buildNoMatchState(),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchInbox,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: list.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, indent: 76, color: AppColors.border),
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
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
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
