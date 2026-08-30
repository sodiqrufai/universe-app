import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

/// Notice Board: official announcements from verified university-official
/// accounts (posts.type = 'notice'). Reverse-chronological, read-only —
/// distinct from the story viewer since this is text content, not media.
class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  List<dynamic> _notices = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/posts/notices');
      if (data['success'] == true) {
        setState(() {
          _notices = data['notices'] ?? [];
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
      appBar: AppBar(title: const Text('Notice Board')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load the notice board', onRetry: _fetch);
    }
    if (_notices.isEmpty) {
      return const EmptyView(
        icon: Icons.campaign_outlined,
        title: 'No notices yet',
        subtitle: 'Official announcements from your university will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _notices.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => _buildNoticeCard(_notices[index]),
      ),
    );
  }

  Widget _buildNoticeCard(dynamic n) {
    final profile = n['profiles'];
    final createdAt = DateTime.tryParse(n['created_at'] ?? '');
    final dateLabel = createdAt != null
        ? DateFormat('MMM d, h:mm a').format(createdAt.toLocal())
        : '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lightPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  profile?['full_name'] ?? 'University Official',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Text(dateLabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(n['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
          if (n['image_url'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Image.network(
                n['image_url'],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
