import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
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
  bool _hasError = false;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await _fetchService();
  }

  Future<void> _fetchService() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/services/listings/${widget.serviceId}');
      if (data['service'] != null) {
        setState(() {
          _service = data['service'];
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

  Future<void> _bookService() async {
    final messageController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Request Booking'),
        content: TextField(
          controller: messageController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add a message (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final data = await ApiService.post(
          '/services/listings/${widget.serviceId}/book',
          {'message': messageController.text.trim()},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['success'] == true ? 'Booking request sent!' : (data['error'] ?? 'Could not send request'),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send request')),
          );
        }
      }
    }
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
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
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      try {
        final data = await ApiService.post(
          '/services/listings/${widget.serviceId}/report',
          {'reason': reason},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['success'] == true ? 'Report submitted' : (data['error'] ?? 'Could not submit report'),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not submit report')),
          );
        }
      }
    }
  }

  Future<void> _deleteService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete this service?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final data = await ApiService.delete('/services/listings/${widget.serviceId}');
        if (data['success'] == true && mounted) {
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not delete service')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete service')),
          );
        }
      }
    }
  }

  Future<void> _messageProvider() async {
    final providerId = _service!['provider_id'];
    if (providerId == null) return;
    try {
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
          SnackBar(content: Text(data['error'] ?? 'Could not start conversation')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start conversation')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_hasError || _service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('Could not load this service'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchService, child: const Text('Retry')),
            ],
          ),
        ),
      );
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
            IconButton(icon: const Icon(Icons.flag_outlined), onPressed: _report),
          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _deleteService,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 220,
              child: PageView(
                children: images
                    .map<Widget>(
                      (img) => Image.network(img['image_url'], fit: BoxFit.cover),
                    )
                    .toList(),
              ),
            )
          else
            Container(
              height: 220,
              color: AppColors.lightPurple,
              child: const Icon(
                Icons.design_services_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _service!['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
                const SizedBox(height: AppSpacing.lg),
                if (_service!['description'] != null)
                  Text(
                    _service!['description'],
                    style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.lightPurple,
                        backgroundImage: profile?['avatar_url'] != null
                            ? NetworkImage(profile['avatar_url'])
                            : null,
                        child: profile?['avatar_url'] == null
                            ? const Icon(Icons.person, size: 18, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
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
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!isMine)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _bookService,
                      child: const Text('Request Booking'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
