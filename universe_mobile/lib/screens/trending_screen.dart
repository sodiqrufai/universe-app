import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

/// Full trending list. Note: the backend endpoint itself caps results
/// at the top 10 tags (a 7-day rolling window), so this doesn't surface
/// more data than the Feed's pill row already has — it's here for
/// easier browsing/tapping on a full page rather than a horizontal
/// scroll, per the "See all" pattern in the spec.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  List<dynamic> _trending = [];
  bool _loading = true;
  bool _hasError = false;

  static const _colors = [
    AppColors.primary,
    AppColors.success,
    AppColors.warning,
    AppColors.info,
  ];

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
      final data = await ApiService.get('/posts/trending');
      if (data['success'] == true) {
        setState(() {
          _trending = data['trending'] ?? [];
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
      appBar: AppBar(title: const Text('Trending on Campus')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load trending topics', onRetry: _fetch);
    }
    if (_trending.isEmpty) {
      return const EmptyView(
        icon: Icons.trending_up,
        title: 'Nothing trending yet',
        subtitle: 'Tag your posts to help topics surface here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _trending.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final t = _trending[i];
        final color = _colors[i % _colors.length];
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => Navigator.of(context).pop(t['label']),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    t['label'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Text(
                  '${t['count']} posts',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
