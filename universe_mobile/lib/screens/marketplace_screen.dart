import '../../config/api_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';
import 'saved_listings_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<dynamic> _listings = [];
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  bool _loading = true;
  bool _hasError = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchListings();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/marketplace/categories'),
      );
      final data = jsonDecode(response.body);
      setState(() {
        _categories = data['categories'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _fetchListings() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await SessionService.getToken();
    final params = <String, String>{};
    if (_selectedCategoryId != null) {
      params['categoryId'] = _selectedCategoryId!;
    }
    if (_searchController.text.trim().isNotEmpty) {
      params['search'] = _searchController.text.trim();
    }
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/marketplace/listings',
    ).replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _listings = data['listings'];
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
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedListingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _fetchListings(),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _fetchListings,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = null);
                      _fetchListings();
                    },
                  ),
                ),
                ..._categories.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c['name']),
                      selected: _selectedCategoryId == c['id'],
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = c['id']);
                        _fetchListings();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 40,
                          color: Colors.black38,
                        ),
                        const SizedBox(height: 12),
                        const Text('Could not load listings'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchListings,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _listings.isEmpty
                ? const Center(
                    child: Text(
                      'No listings yet — be the first to sell something!',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchListings,
                    color: AppColors.primary,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _listings.length,
                      itemBuilder: (context, index) =>
                          _buildListingCard(_listings[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final created = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateListingScreen()),
          );
          if (created == true) _fetchListings();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildListingCard(dynamic listing) {
    final images = listing['listing_images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images.first['image_url'] : null;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listingId: listing['id']),
          ),
        );
        _fetchListings();
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing['title'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₦${listing['price']}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
}

