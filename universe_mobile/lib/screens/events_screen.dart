import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import 'my_events_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<dynamic> _events = [];
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchEvents();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/events/categories'));
      final data = jsonDecode(response.body);
      setState(() {
        _categories = data['categories'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await SessionService.getToken();
    final params = <String, String>{};
    if (_selectedCategoryId != null) params['categoryId'] = _selectedCategoryId!;
    final uri = Uri.parse('${ApiConfig.baseUrl}/events').replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _events = data['events'];
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
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyEventsScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = null);
                      _fetchEvents();
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
                        _fetchEvents();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
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
                            const Text('Could not load events'),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _fetchEvents, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _events.isEmpty
                        ? const Center(child: Text('No upcoming events yet'))
                        : RefreshIndicator(
                            onRefresh: _fetchEvents,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _events.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildEventCard(_events[index]),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final created = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (created == true) _fetchEvents();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final startsAt = DateTime.tryParse(event['starts_at'] ?? '');
    final dateLabel = startsAt != null ? DateFormat('EEE, MMM d • h:mm a').format(startsAt) : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event['id'])),
          );
          _fetchEvents();
        },
        child: Row(
          children: [
            event['cover_image_url'] != null
                ? Image.network(event['cover_image_url'], width: 80, height: 80, fit: BoxFit.cover)
                : Container(
                    width: 80,
                    height: 80,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: const Icon(Icons.event, color: AppColors.primary),
                  ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event['title'], style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(dateLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    if (event['location'] != null)
                      Text(event['location'], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('${event['goingCount']} going', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
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