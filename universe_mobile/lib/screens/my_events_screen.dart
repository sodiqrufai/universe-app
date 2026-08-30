import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import 'event_detail_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  List<dynamic> _events = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchMyEvents();
  }

  Future<void> _fetchMyEvents() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/events/mine');
      setState(() {
        _events = data['events'] ?? [];
        _loading = false;
      });
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
      appBar: AppBar(title: const Text('My Events')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load your events', onRetry: _fetchMyEvents);
    }
    if (_events.isEmpty) {
      return const EmptyView(
        icon: Icons.event_outlined,
        title: "You haven't RSVPed to any events yet",
        subtitle: 'Events you say you\'re going to show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchMyEvents,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = _events[index];
          final event = entry['events'];
          if (event == null) return const SizedBox.shrink();
          final startsAt = DateTime.tryParse(event['starts_at'] ?? '');
          final dateLabel = startsAt != null
              ? DateFormat('MMM d • h:mm a').format(startsAt.toLocal())
              : '';
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightPurple,
                child: const Icon(Icons.event, color: AppColors.primary),
              ),
              title: Text(event['title'] ?? ''),
              subtitle: Text('$dateLabel • ${entry['status']}'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(eventId: event['id']),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
