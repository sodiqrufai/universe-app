import '../../config/api_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import 'chat_detail_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String serviceId;
  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  Map<String, dynamic>? _service;
  bool _loading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _fetchService();
  }

  Future<void> _loadUserId() async {
    final id = await SessionService.getUserId();
    setState(() {
      _myUserId = id;
    });
  }

  Future<void> _fetchService() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/services/listings/${widget.serviceId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _service = data['service'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _bookService() async {
    final messageController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Booking'),
        content: TextField(
          controller: messageController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add a message (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final token = await SessionService.getToken();
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/services/listings/${widget.serviceId}/book',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': messageController.text.trim()}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['success'] == true
                  ? 'Booking request sent!'
                  : (data['error'] ?? 'Failed'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report this service'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      final token = await SessionService.getToken();
      await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/services/listings/${widget.serviceId}/report',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report submitted')));
      }
    }
  }

  Future<void> _deleteService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this service?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final token = await SessionService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/services/listings/${widget.serviceId}'),
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_service == null) {
      return const Scaffold(body: Center(child: Text('Service not found')));
    }

    final images = _service!['service_images'] as List<dynamic>? ?? [];
    final profile = _service!['profiles'];
    final isMine = _service!['provider_id'] == _myUserId;
    final priceLabel = _service!['price'] != null
        ? '₦${_service!['price']}${_service!['price_type'] == 'hourly' ? '/hr' : ''}'
        : 'Negotiable';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service'),
        actions: [
          if (!isMine)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              onPressed: _report,
            ),
          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteService,
            ),
        ],
      ),
      body: ListView(
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 220,
              child: PageView(
                children: images
                    .map<Widget>(
                      (img) =>
                          Image.network(img['image_url'], fit: BoxFit.cover),
                    )
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _service!['title'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  priceLabel,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_service!['description'] != null)
                  Text(
                    _service!['description'],
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage: profile?['avatar_url'] != null
                          ? NetworkImage(profile['avatar_url'])
                          : null,
                      child: profile?['avatar_url'] == null
                          ? const Icon(
                              Icons.person,
                              size: 16,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile?['full_name'] ?? 'Provider',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!isMine)
                      TextButton.icon(
                        onPressed: _messageProvider,
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Message'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isMine)
                  ElevatedButton(
                    onPressed: _bookService,
                    child: const Text('Request Booking'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _messageProvider() async {
    final providerId = _service!['provider_id'];
    if (providerId == null) return;

    final data = await ApiService.post('/chat/direct', {
      'otherUserId': providerId,
    });
    if (data['success'] == true && mounted) {
      final profile = _service!['profiles'];
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: data['conversationId'],
            title: profile?['full_name'] ?? 'Chat',
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['error'] ?? 'Could not start conversation'),
        ),
      );
    }
  }
}

