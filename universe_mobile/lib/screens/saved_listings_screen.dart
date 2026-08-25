import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'listing_detail_screen.dart';

class SavedListingsScreen extends StatefulWidget {
  const SavedListingsScreen({super.key});

  @override
  State<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends State<SavedListingsScreen> {
  List<dynamic> _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSaved();
  }

  Future<void> _fetchSaved() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/marketplace/saved'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _listings = data['listings'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Items')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _listings.isEmpty
              ? const Center(child: Text('No saved items yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final l = _listings[index];
                    final images = l['listing_images'] as List<dynamic>? ?? [];
                    final imageUrl = images.isNotEmpty ? images.first['image_url'] : null;
                    return Card(
                      child: ListTile(
                        leading: imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.image_outlined, color: AppColors.primary),
                        title: Text(l['title']),
                        subtitle: Text('₦${l['price']}'),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: l['id'])),
                          );
                          _fetchSaved();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}