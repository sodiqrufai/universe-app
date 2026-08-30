import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _asCustomer = [];
  List<dynamic> _asProvider = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/services/bookings');
      setState(() {
        _asCustomer = data['asCustomer'] ?? [];
        _asProvider = data['asProvider'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _respond(String bookingId, String status) async {
    try {
      final data = await ApiService.patch('/services/bookings/$bookingId', {
        'status': status,
      });
      if (data['success'] == true) {
        _fetchBookings();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not update booking')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update booking')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Requested'),
            Tab(text: 'Received'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load your bookings', onRetry: _fetchBookings);
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAsCustomerList(),
        _buildAsProviderList(),
      ],
    );
  }

  Widget _buildAsCustomerList() {
    if (_asCustomer.isEmpty) {
      return const EmptyView(
        icon: Icons.event_note_outlined,
        title: 'No bookings requested yet',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchBookings,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _asCustomer.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final b = _asCustomer[index];
          return Card(
            child: ListTile(
              title: Text(b['services']?['title'] ?? 'Service'),
              subtitle: Text(
                'Provider: ${b['services']?['profiles']?['full_name'] ?? 'Unknown'}',
              ),
              trailing: Chip(
                label: Text(b['status']),
                backgroundColor: _statusColor(b['status']).withValues(alpha: 0.15),
                labelStyle: TextStyle(color: _statusColor(b['status'])),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAsProviderList() {
    if (_asProvider.isEmpty) {
      return const EmptyView(
        icon: Icons.event_note_outlined,
        title: 'No booking requests received yet',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchBookings,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _asProvider.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final b = _asProvider[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b['services']?['title'] ?? 'Service',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'From: ${b['profiles']?['full_name'] ?? 'Customer'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (b['message'] != null && b['message'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(b['message'], style: const TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(height: 8),
                  if (b['status'] == 'pending')
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _respond(b['id'], 'accepted'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _respond(b['id'], 'rejected'),
                          child: const Text('Reject'),
                        ),
                      ],
                    )
                  else
                    Chip(
                      label: Text(b['status']),
                      backgroundColor: _statusColor(b['status']).withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: _statusColor(b['status'])),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
