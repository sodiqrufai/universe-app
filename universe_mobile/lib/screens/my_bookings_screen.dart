import '../../config/api_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loading = true;
    });
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/services/bookings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _asCustomer = data['asCustomer'] ?? [];
        _asProvider = data['asProvider'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _respond(String bookingId, String status) async {
    final token = await SessionService.getToken();
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/services/bookings/$bookingId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    _fetchBookings();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return AppColors.primary;
      default:
        return Colors.orange;
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
          tabs: const [
            Tab(text: 'Requested'),
            Tab(text: 'Received'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _asCustomer.isEmpty
                    ? const Center(child: Text('No bookings requested yet'))
                    : ListView.separated(
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
                                backgroundColor: _statusColor(
                                  b['status'],
                                ).withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: _statusColor(b['status']),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                _asProvider.isEmpty
                    ? const Center(
                        child: Text('No booking requests received yet'),
                      )
                    : ListView.separated(
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'From: ${b['profiles']?['full_name'] ?? 'Customer'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  if (b['message'] != null &&
                                      b['message'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        b['message'],
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  if (b['status'] == 'pending')
                                    Row(
                                      children: [
                                        ElevatedButton(
                                          onPressed: () =>
                                              _respond(b['id'], 'accepted'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.success,
                                          ),
                                          child: const Text('Accept'),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () =>
                                              _respond(b['id'], 'rejected'),
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    )
                                  else
                                    Chip(
                                      label: Text(b['status']),
                                      backgroundColor: _statusColor(
                                        b['status'],
                                      ).withValues(alpha: 0.15),
                                      labelStyle: TextStyle(
                                        color: _statusColor(b['status']),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}

