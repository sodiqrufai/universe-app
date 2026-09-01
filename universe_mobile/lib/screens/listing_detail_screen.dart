import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/app_image.dart';
import 'chat_detail_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  bool _hasError = false;
  String? _myUserId;
  List<dynamic> _offers = [];
  bool _loadingOffers = false;
  int _imagePage = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await _fetchListing();
  }

  Future<void> _fetchListing() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get(
        '/marketplace/listings/${widget.listingId}',
      );
      if (data['success'] == true || data['listing'] != null) {
        setState(() {
          _listing = data['listing'];
          _loading = false;
        });
        if (_listing != null && _listing!['seller_id'] == _myUserId) {
          _fetchOffers();
        }
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

  Future<void> _fetchOffers() async {
    setState(() => _loadingOffers = true);
    try {
      final data = await ApiService.get(
        '/marketplace/listings/${widget.listingId}/offers',
      );
      setState(() {
        _offers = data['offers'] ?? [];
        _loadingOffers = false;
      });
    } catch (_) {
      setState(() => _loadingOffers = false);
    }
  }

  Future<void> _respondToOffer(String offerId, String status) async {
    try {
      final data = await ApiService.patch('/marketplace/offers/$offerId', {
        'status': status,
      });
      if (data['success'] == true) {
        _fetchOffers();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not respond to offer')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not respond to offer')),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    final wasSaved = _listing!['isSaved'] == true;
    setState(() => _listing!['isSaved'] = !wasSaved);
    try {
      final data = await ApiService.post(
        '/marketplace/listings/${widget.listingId}/save',
        {},
      );
      if (data['success'] != true && mounted) {
        setState(() => _listing!['isSaved'] = wasSaved);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save this listing')));
      }
    } catch (_) {
      if (mounted) setState(() => _listing!['isSaved'] = wasSaved);
    }
  }

  Future<void> _makeOffer() async {
    final amountController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Make an Offer'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Your offer (₦)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
    if (confirmed == true && amountController.text.trim().isNotEmpty) {
      try {
        final data = await ApiService.post(
          '/marketplace/listings/${widget.listingId}/offers',
          {'amount': amountController.text.trim()},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['success'] == true ? 'Offer sent!' : (data['error'] ?? 'Could not send offer'),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send offer')),
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
        title: const Text('Report this listing'),
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
          '/marketplace/listings/${widget.listingId}/report',
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

  Future<void> _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete this listing?'),
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
        final data = await ApiService.delete(
          '/marketplace/listings/${widget.listingId}',
        );
        if (data['success'] == true && mounted) {
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not delete listing')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete listing')),
          );
        }
      }
    }
  }

  Future<void> _messageSeller() async {
    final sellerId = _listing!['seller_id'];
    if (sellerId == null) return;
    try {
      final data = await ApiService.post('/chat/direct', {
        'otherUserId': sellerId,
      });
      if (data['success'] == true && mounted) {
        final profile = _listing!['profiles'];
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
    if (_hasError || _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('Could not load this listing'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchListing, child: const Text('Retry')),
            ],
          ),
        ),
      );
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
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Report listing',
              onPressed: _report,
            ),
          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Delete listing',
              onPressed: _deleteListing,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildImageCarousel(images),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _listing!['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: AppColors.primary,
                      ),
                      tooltip: isSaved ? 'Unsave listing' : 'Save listing',
                      onPressed: _toggleSave,
                    ),
                  ],
                ),
                Text(
                  '₦${_listing!['price']}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_listing!['condition'] != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _pill(_listing!['condition']),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_listing!['description'] != null)
                  Text(
                    _listing!['description'],
                    style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                  ),
                const SizedBox(height: AppSpacing.xl),
                _buildSellerRow(profile, isMine),
                const SizedBox(height: AppSpacing.xl),
                if (!isMine)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _makeOffer,
                      child: const Text('Make an Offer'),
                    ),
                  ),
                if (isMine) ...[
                  const Divider(height: 32),
                  const Text(
                    'Offers Received',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildOffersSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<dynamic> images) {
    if (images.isEmpty) {
      return Container(
        height: 260,
        color: AppColors.lightPurple,
        child: const Icon(Icons.image_outlined, size: 60, color: AppColors.primary),
      );
    }
    return Stack(
      children: [
        SizedBox(
          height: 260,
          child: PageView(
            onPageChanged: (i) => setState(() => _imagePage = i),
            children: images
                .map<Widget>(
                  (img) => AppNetworkImage(img['image_url']),
                )
                .toList(),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _imagePage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _imagePage
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSellerRow(dynamic profile, bool isMine) {
    return Container(
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
              profile?['full_name'] ?? 'Seller',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (!isMine)
            TextButton.icon(
              onPressed: _messageSeller,
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Message'),
            ),
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    if (_loadingOffers) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_offers.isEmpty) {
      return const Text('No offers yet', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      children: _offers.map((o) {
        final buyer = o['profiles'];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₦${o['amount']} from ${buyer?['full_name'] ?? 'Buyer'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      o['status'] ?? '',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (o['status'] == 'pending') ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                  tooltip: 'Accept offer',
                  onPressed: () => _respondToOffer(o['id'], 'accepted'),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  tooltip: 'Decline offer',
                  onPressed: () => _respondToOffer(o['id'], 'rejected'),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
