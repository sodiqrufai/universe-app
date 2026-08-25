import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  String? _myUserId;
  List<dynamic> _offers = [];
  bool _loadingOffers = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadUserId();
    await _fetchListing();
  }

  Future<void> _loadUserId() async {
    final id = await SessionService.getUserId();
    setState(() {
      _myUserId = id;
    });
  }

  Future<void> _fetchListing() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/marketplace/listings/${widget.listingId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _listing = data['listing'];
        _loading = false;
      });
      if (_listing != null && _listing!['seller_id'] == _myUserId) {
        _fetchOffers();
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchOffers() async {
    setState(() {
      _loadingOffers = true;
    });
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/marketplace/listings/${widget.listingId}/offers'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _offers = data['offers'] ?? [];
        _loadingOffers = false;
      });
    } catch (e) {
      setState(() {
        _loadingOffers = false;
      });
    }
  }

  Future<void> _respondToOffer(String offerId, String status) async {
    final token = await SessionService.getToken();
    final response = await http.patch(
      Uri.parse('http://localhost:3000/marketplace/offers/$offerId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'status': status}),
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      _fetchOffers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to respond (status ${response.statusCode})')),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    final token = await SessionService.getToken();
    await http.post(
      Uri.parse('http://localhost:3000/marketplace/listings/${widget.listingId}/save'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _fetchListing();
  }

  Future<void> _makeOffer() async {
    final amountController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make an Offer'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Your offer (₦)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send Offer')),
        ],
      ),
    );
    if (confirmed == true && amountController.text.trim().isNotEmpty) {
      final token = await SessionService.getToken();
      final response = await http.post(
        Uri.parse('http://localhost:3000/marketplace/listings/${widget.listingId}/offers'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'amount': amountController.text.trim()}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['success'] == true ? 'Offer sent!' : (data['error'] ?? 'Failed'))),
        );
      }
    }
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report this listing'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, reasonController.text.trim()), child: const Text('Report')),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      final token = await SessionService.getToken();
      await http.post(
        Uri.parse('http://localhost:3000/marketplace/listings/${widget.listingId}/report'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'reason': reason}),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
    }
  }

  Future<void> _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final token = await SessionService.getToken();
      final response = await http.delete(
        Uri.parse('http://localhost:3000/marketplace/listings/${widget.listingId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to delete')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_listing == null) {
      return const Scaffold(body: Center(child: Text('Listing not found')));
    }

    final images = _listing!['listing_images'] as List<dynamic>? ?? [];
    final profile = _listing!['profiles'];
    final isMine = _listing!['seller_id'] == _myUserId;
    final isSaved = _listing!['isSaved'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing'),
        actions: [
          if (!isMine)
            IconButton(icon: const Icon(Icons.flag_outlined), onPressed: _report),
          if (isMine)
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _deleteListing),
        ],
      ),
      body: ListView(
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 260,
              child: PageView(
                children: images.map<Widget>((img) => Image.network(img['image_url'], fit: BoxFit.cover)).toList(),
              ),
            )
          else
            Container(
              height: 260,
              color: AppColors.primary.withValues(alpha: 0.08),
              child: const Icon(Icons.image_outlined, size: 60, color: AppColors.primary),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_listing!['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: AppColors.primary),
                      onPressed: _toggleSave,
                    ),
                  ],
                ),
                Text('₦${_listing!['price']}', style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_listing!['condition'] != null)
                  Chip(label: Text(_listing!['condition'])),
                const SizedBox(height: 16),
                if (_listing!['description'] != null)
                  Text(_listing!['description'], style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                      child: profile?['avatar_url'] == null ? const Icon(Icons.person, size: 16, color: AppColors.primary) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(profile?['full_name'] ?? 'Seller', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isMine)
                  ElevatedButton(
                    onPressed: _makeOffer,
                    child: const Text('Make an Offer'),
                  ),
                if (isMine) ...[
                  const Divider(height: 32),
                  const Text('Offers Received', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_loadingOffers)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  else if (_offers.isEmpty)
                    const Text('No offers yet', style: TextStyle(color: Colors.black54))
                  else
                    ..._offers.map((o) {
                      final buyer = o['profiles'];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('₦${o['amount']} from ${buyer?['full_name'] ?? 'Buyer'}'),
                          subtitle: Text(o['status']),
                          trailing: o['status'] == 'pending'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: AppColors.success),
                                      onPressed: () => _respondToOffer(o['id'], 'accepted'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _respondToOffer(o['id'], 'rejected'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}