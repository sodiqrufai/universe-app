import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/app_image.dart';
import 'post_detail_screen.dart';
import 'listing_detail_screen.dart';
import 'service_detail_screen.dart';
import 'event_detail_screen.dart';

/// Global search across posts, marketplace listings, services, events,
/// and course resources — one query, one debounce, results grouped by
/// type. The backend paginates all 5 types together under the same
/// page/pageSize (not independently per type), so "load more" here
/// advances one shared page and appends into every section at once.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String _query = '';
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasError = false;
  int _page = 1;
  static const _pageSize = 10;

  Map<String, dynamic> _results = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      if (trimmed == _query) return;
      setState(() => _query = trimmed);
      if (trimmed.length >= 2) {
        _search(reset: true);
      } else {
        setState(() => _results = {});
      }
    });
  }

  bool get _sectionsHaveMore {
    for (final section in _results.values) {
      final items = (section['items'] as List<dynamic>? ?? []);
      final total = section['total'] ?? 0;
      if (items.length < total) return true;
    }
    return false;
  }

  Future<void> _search({required bool reset}) async {
    if (_query.length < 2) return;
    setState(() {
      if (reset) {
        _page = 1;
        _loading = true;
        _hasError = false;
      }
    });
    try {
      final data = await ApiService.get(
        '/search?q=${Uri.encodeQueryComponent(_query)}&page=$_page&pageSize=$_pageSize',
      );
      if (data['success'] == true) {
        setState(() {
          _results = Map<String, dynamic>.from(data['results'] ?? {});
          _loading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _query.length < 2 || !_sectionsHaveMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final data = await ApiService.get(
        '/search?q=${Uri.encodeQueryComponent(_query)}&page=$nextPage&pageSize=$_pageSize',
      );
      if (data['success'] == true) {
        final newResults = Map<String, dynamic>.from(data['results'] ?? {});
        setState(() {
          for (final type in newResults.keys) {
            final existing = (_results[type]?['items'] as List<dynamic>?) ?? [];
            final incoming = (newResults[type]?['items'] as List<dynamic>?) ?? [];
            _results[type] = {
              'items': [...existing, ...incoming],
              'total': newResults[type]?['total'] ?? existing.length,
            };
          }
          _page = nextPage;
          _loadingMore = false;
        });
      } else {
        setState(() => _loadingMore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openResult(String type, dynamic item) {
    switch (type) {
      case 'posts':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: item)),
        );
        break;
      case 'listings':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: item['id'])),
        );
        break;
      case 'services':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item['id'])),
        );
        break;
      case 'events':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: item['id'])),
        );
        break;
      case 'resources':
        if (item['file_path'] != null) {
          launchUrl(Uri.parse(item['file_path']), mode: LaunchMode.externalApplication);
        }
        break;
    }
  }

  static const _sectionLabels = {
    'posts': 'Posts',
    'listings': 'Marketplace',
    'services': 'Services',
    'events': 'Events',
    'resources': 'Resources',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search UniVerse...',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Search posts, listings, services, events, and course resources.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not search right now', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _search(reset: true), child: const Text('Retry')),
          ],
        ),
      );
    }

    final nonEmptySections = _sectionLabels.keys.where((type) {
      final items = (_results[type]?['items'] as List<dynamic>?) ?? [];
      return items.isNotEmpty;
    }).toList();

    if (nonEmptySections.isEmpty) {
      return Center(
        child: Text('No results for "$_query"', style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        for (final type in nonEmptySections) _buildSection(type),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection(String type) {
    final section = _results[type];
    final items = (section['items'] as List<dynamic>?) ?? [];
    final total = section['total'] ?? items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Text(
            '${_sectionLabels[type]} ($total)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
        ...items.map((item) => _buildResultTile(type, item)),
      ],
    );
  }

  Widget _buildResultTile(String type, dynamic item) {
    final title = switch (type) {
      'posts' => item['profiles']?['full_name'] ?? 'Student',
      'resources' => item['title'] ?? '',
      _ => item['title'] ?? '',
    };
    final subtitle = switch (type) {
      'posts' => item['content'] ?? '',
      'listings' => item['price'] != null ? '₦${item['price']}' : '',
      'services' => item['price'] != null ? '₦${item['price']}' : '',
      'events' => item['starts_at'] ?? '',
      'resources' => item['resource_type'] ?? '',
      _ => '',
    };
    final images = switch (type) {
      'listings' => item['listing_images'] as List<dynamic>? ?? [],
      'services' => item['service_images'] as List<dynamic>? ?? [],
      _ => const <dynamic>[],
    };
    final imageUrl = images.isNotEmpty ? images.first['image_url'] : null;

    return ListTile(
      leading: imageUrl != null
          ? AppNetworkImage(imageUrl, width: 44, height: 44, borderRadius: BorderRadius.circular(8))
          : CircleAvatar(
              backgroundColor: AppColors.lightPurple,
              child: Icon(_iconFor(type), color: AppColors.primary, size: 18),
            ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _openResult(type, item),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'posts' => Icons.article_outlined,
        'listings' => Icons.storefront_outlined,
        'services' => Icons.handyman_outlined,
        'events' => Icons.event_outlined,
        'resources' => Icons.description_outlined,
        _ => Icons.search,
      };
}
