import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/session_service.dart';
import '../create_service_screen.dart';
import '../service_detail_screen.dart';
// import '../my_bookings_screen.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  List<dynamic> _services = [];
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  bool _loading = true;
  bool _hasError = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchServices();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/services/categories'));
      final data = jsonDecode(response.body);
      setState(() {
        _categories = data['categories'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _fetchServices() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await SessionService.getToken();
    final params = <String, String>{};
    if (_selectedCategoryId != null) params['categoryId'] = _selectedCategoryId!;
    if (_searchController.text.trim().isNotEmpty) params['search'] = _searchController.text.trim();
    final uri = Uri.parse('http://localhost:3000/services/listings')
        .replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _services = data['services'];
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _fetchServices(),
              decoration: InputDecoration(
                hintText: 'Search services...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _fetchServices),
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
                      _fetchServices();
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
                        _fetchServices();
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off, size: 40, color: Colors.black38),
                            const SizedBox(height: 12),
                            const Text('Could not load services'),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _fetchServices, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _services.isEmpty
                        ? const Center(child: Text('No services yet — be the first to offer one!'))
                        : RefreshIndicator(
                            onRefresh: _fetchServices,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _services.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildServiceCard(_services[index]),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final created = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateServiceScreen()),
          );
          if (created == true) _fetchServices();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildServiceCard(dynamic service) {
    final images = service['service_images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images.first['image_url'] : null;
    final profile = service['profiles'];
    final priceLabel = service['price'] != null
        ? '₦${service['price']}${service['price_type'] == 'hourly' ? '/hr' : ''}'
        : 'Negotiable';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: service['id'])),
          );
          _fetchServices();
        },
        child: Row(
          children: [
            imageUrl != null
                ? Image.network(imageUrl, width: 90, height: 90, fit: BoxFit.cover)
                : Container(
                    width: 90,
                    height: 90,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: const Icon(Icons.handyman_outlined, color: AppColors.primary),
                  ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service['title'], style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(priceLabel, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(profile?['full_name'] ?? 'Provider', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}