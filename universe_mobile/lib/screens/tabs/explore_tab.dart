import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/state_views.dart';
import '../course_detail_screen.dart';
import '../event_detail_screen.dart';
import '../service_detail_screen.dart';
import '../listing_detail_screen.dart';
import '../create_event_screen.dart';
import '../create_service_screen.dart';
import '../create_listing_screen.dart';

enum _ExploreType { education, event, service, marketplace }

class _ExploreItem {
  final _ExploreType type;
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final dynamic raw;

  _ExploreItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.raw,
  });
}

/// Explore: one browsing surface for Education, Events, Services, and
/// Marketplace — a shared feed with a pill filter, instead of four
/// separate destinations the user has to already know exist.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  _ExploreType? _filter; // null = All
  List<_ExploreItem> _items = [];
  bool _loading = true;
  bool _partialFailure = false;
  bool _totalFailure = false;
  final _scrollController = ScrollController();

  // None of Education/Events/Services/Marketplace support server-side
  // pagination yet (checked all 4 controllers directly) — everything
  // is fetched in one shot on _fetchAll(). This reveals it into the
  // grid in chunks as the user scrolls instead of building every cell
  // at once, so a large combined result set still scrolls smoothly.
  // When those endpoints do get real pagination, swap _loadMoreLocal's
  // local-slice step for an actual page fetch — the scroll-listener
  // and footer plumbing stay the same.
  static const _chunkSize = 20;
  int _visibleCount = _chunkSize;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _revealMore();
    }
  }

  void _revealMore() {
    if (_visibleCount >= _filteredItems.length) return;
    setState(() => _visibleCount = (_visibleCount + _chunkSize).clamp(0, _filteredItems.length));
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _partialFailure = false;
      _totalFailure = false;
      _visibleCount = _chunkSize;
    });

    final results = await Future.wait([
      _fetchEducation(),
      _fetchEvents(),
      _fetchServices(),
      _fetchMarketplace(),
    ]);

    final items = <_ExploreItem>[];
    var failures = 0;
    for (final r in results) {
      if (r == null) {
        failures++;
      } else {
        items.addAll(r);
      }
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _totalFailure = failures == results.length;
      _partialFailure = failures > 0 && failures < results.length;
    });
  }

  Future<List<_ExploreItem>?> _fetchEducation() async {
    try {
      final data = await ApiService.get('/education/courses');
      if (data['success'] != true) return null;
      final courses = data['courses'] as List<dynamic>? ?? [];
      return courses
          .map(
            (c) => _ExploreItem(
              type: _ExploreType.education,
              id: c['id'].toString(),
              title: c['name'] ?? '',
              subtitle: c['code'] ?? '',
              imageUrl: null,
              raw: c,
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<_ExploreItem>?> _fetchEvents() async {
    try {
      final data = await ApiService.get('/events');
      if (data['success'] != true) return null;
      final events = data['events'] as List<dynamic>? ?? [];
      return events
          .map(
            (e) => _ExploreItem(
              type: _ExploreType.event,
              id: e['id'].toString(),
              title: e['title'] ?? '',
              subtitle: e['location'] ?? 'Campus event',
              imageUrl: e['cover_image_url'],
              raw: e,
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<_ExploreItem>?> _fetchServices() async {
    try {
      final data = await ApiService.get('/services/listings');
      if (data['success'] != true) return null;
      final services = data['listings'] as List<dynamic>? ?? [];
      return services.map((s) {
        final images = s['service_images'] as List<dynamic>? ?? [];
        final priceLabel = s['price'] != null
            ? '₦${s['price']}${s['price_type'] == 'hourly' ? '/hr' : ''}'
            : 'Negotiable';
        return _ExploreItem(
          type: _ExploreType.service,
          id: s['id'].toString(),
          title: s['title'] ?? '',
          subtitle: priceLabel,
          imageUrl: images.isNotEmpty ? images.first['image_url'] : null,
          raw: s,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<_ExploreItem>?> _fetchMarketplace() async {
    try {
      final data = await ApiService.get('/marketplace/listings');
      if (data['success'] != true) return null;
      final listings = data['listings'] as List<dynamic>? ?? [];
      return listings.map((l) {
        final images = l['listing_images'] as List<dynamic>? ?? [];
        return _ExploreItem(
          type: _ExploreType.marketplace,
          id: l['id'].toString(),
          title: l['title'] ?? '',
          subtitle: '₦${l['price']}',
          imageUrl: images.isNotEmpty ? images.first['image_url'] : null,
          raw: l,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  List<_ExploreItem> get _filteredItems {
    if (_filter == null) return _items;
    return _items.where((i) => i.type == _filter).toList();
  }

  void _openItem(_ExploreItem item) {
    switch (item.type) {
      case _ExploreType.education:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CourseDetailScreen(course: item.raw)),
        );
        break;
      case _ExploreType.event:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: item.id)),
        );
        break;
      case _ExploreType.service:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id)),
        );
        break;
      case _ExploreType.marketplace:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: item.id)),
        );
        break;
    }
  }

  Future<void> _create() async {
    if (_filter == _ExploreType.event) return _createEvent();
    if (_filter == _ExploreType.service) return _createService();
    if (_filter == _ExploreType.marketplace) return _createListing();

    final choice = await showModalBottomSheet<_ExploreType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'What do you want to create?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
              title: const Text('Marketplace listing'),
              onTap: () => Navigator.pop(context, _ExploreType.marketplace),
            ),
            ListTile(
              leading: const Icon(Icons.design_services_outlined, color: AppColors.primary),
              title: const Text('Service'),
              onTap: () => Navigator.pop(context, _ExploreType.service),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined, color: AppColors.primary),
              title: const Text('Event'),
              onTap: () => Navigator.pop(context, _ExploreType.event),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == _ExploreType.event) return _createEvent();
    if (choice == _ExploreType.service) return _createService();
    if (choice == _ExploreType.marketplace) return _createListing();
  }

  Future<void> _createEvent() async {
    final created = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateEventScreen()));
    if (created == true) _fetchAll();
  }

  Future<void> _createService() async {
    final created = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateServiceScreen()));
    if (created == true) _fetchAll();
  }

  Future<void> _createListing() async {
    final created = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateListingScreen()));
    if (created == true) _fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildPillRow(),
          ),
          if (_partialFailure)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPartialFailureBanner(),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _filter == _ExploreType.education
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _create,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView();
    }
    if (_totalFailure) {
      return ErrorView(message: 'Could not load Explore', onRetry: _fetchAll);
    }
    final items = _filteredItems;
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAll,
        color: AppColors.primary,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('Nothing here yet — check back soon.')),
          ],
        ),
      );
    }
    final visibleItems = items.take(_visibleCount).toList();
    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.primary,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: visibleItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, i) => _buildCard(visibleItems[i]),
      ),
    );
  }

  Widget _buildPartialFailureBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Some content could not load.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          TextButton(onPressed: _fetchAll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPillRow() {
    final options = <(_ExploreType?, String, IconData)>[
      (null, 'All', Icons.apps),
      (_ExploreType.education, 'Education', Icons.school_outlined),
      (_ExploreType.event, 'Events', Icons.event_outlined),
      (_ExploreType.service, 'Services', Icons.design_services_outlined),
      (_ExploreType.marketplace, 'Marketplace', Icons.storefront_outlined),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (type, label, icon) = options[i];
          final selected = _filter == type;
          return ChoiceChip(
            avatar: Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            label: Text(label),
            selected: selected,
            onSelected: (_) => setState(() {
              _filter = type;
              _visibleCount = _chunkSize;
            }),
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
        },
      ),
    );
  }

  Widget _buildCard(_ExploreItem item) {
    final badge = _badgeFor(item.type);
    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item.imageUrl != null
                        ? AppNetworkImage(item.imageUrl!)
                        : Container(
                            color: badge.$2.withValues(alpha: 0.08),
                            child: Icon(badge.$1, color: badge.$2, size: 36),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        badge.$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: badge.$2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _badgeFor(_ExploreType type) {
    switch (type) {
      case _ExploreType.education:
        return (Icons.school_outlined, AppColors.info, 'Course');
      case _ExploreType.event:
        return (Icons.event_outlined, AppColors.primary, 'Event');
      case _ExploreType.service:
        return (Icons.design_services_outlined, AppColors.success, 'Service');
      case _ExploreType.marketplace:
        return (Icons.storefront_outlined, AppColors.warning, 'Marketplace');
    }
  }
}
