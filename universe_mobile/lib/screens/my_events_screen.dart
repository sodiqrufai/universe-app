import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'event_detail_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyEvents();
  }

  Future<void> _fetchMyEvents() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/events/mine'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _events = data['events'] ?? [];
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
      appBar: AppBar(title: const Text('My Events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _events.isEmpty
              ? const Center(child: Text("You haven't RSVPed to any events yet"))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = _events[index];
                    final event = entry['events'];
                    if (event == null) return const SizedBox.shrink();
                    final startsAt = DateTime.tryParse(event['starts_at'] ?? '');
                    final dateLabel = startsAt != null ? DateFormat('MMM d • h:mm a').format(startsAt.toLocal()) : '';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: const Icon(Icons.event, color: AppColors.primary),
                        ),
                        title: Text(event['title'] ?? ''),
                        subtitle: Text('$dateLabel • ${entry['status']}'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event['id'])),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}