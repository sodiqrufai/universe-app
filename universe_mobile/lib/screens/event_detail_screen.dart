import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  bool _loading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await _fetchEvent();
  }

  Future<void> _fetchEvent() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/events/${widget.eventId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _event = data['event'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _rsvp(String status) async {
    final token = await SessionService.getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/events/${widget.eventId}/rsvp'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'status': status}),
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      _fetchEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'going' ? "You're going!" : 'Marked as interested')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to RSVP')),
        );
      }
    }
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report this event'),
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
        Uri.parse('${ApiConfig.baseUrl}/events/${widget.eventId}/report'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'reason': reason}),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
    }
  }

  Future<void> _cancelEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text('Everyone who RSVPed will see it as cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Cancel')),
        ],
      ),
    );
    if (confirm == true) {
      final token = await SessionService.getToken();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/events/${widget.eventId}/cancel'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchEvent();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_event == null) {
      return const Scaffold(body: Center(child: Text('Event not found')));
    }

    final startsAt = DateTime.tryParse(_event!['starts_at'] ?? '');
    final dateLabel = startsAt != null ? DateFormat('EEEE, MMM d • h:mm a').format(startsAt.toLocal()) : '';
    final profile = _event!['profiles'];
    final isMine = _event!['organizer_id'] == _myUserId;
    final isCancelled = _event!['status'] == 'cancelled';
    final myRsvp = _event!['myRsvp'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          if (!isMine) IconButton(icon: const Icon(Icons.flag_outlined), onPressed: _report),
          if (isMine && !isCancelled)
            IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.red), onPressed: _cancelEvent),
        ],
      ),
      body: ListView(
        children: [
          if (_event!['cover_image_url'] != null)
            Image.network(_event!['cover_image_url'], height: 220, fit: BoxFit.cover, width: double.infinity)
          else
            Container(
              height: 220,
              color: AppColors.primary.withValues(alpha: 0.08),
              child: const Icon(Icons.event, size: 60, color: AppColors.primary),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 8),
                Text(_event!['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(dateLabel, style: const TextStyle(color: Colors.black54)),
                if (_event!['location'] != null)
                  Text(_event!['location'], style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Text('${_event!['goingCount']} going • ${_event!['interestedCount']} interested', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                if (_event!['description'] != null)
                  Text(_event!['description'], style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                      child: profile?['avatar_url'] == null ? const Icon(Icons.person, size: 16, color: AppColors.primary) : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Organized by ${profile?['full_name'] ?? 'Someone'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isCancelled)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rsvp('interested'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: myRsvp == 'interested' ? AppColors.primary.withValues(alpha: 0.1) : null,
                          ),
                          child: const Text('Interested'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _rsvp('going'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: myRsvp == 'going' ? AppColors.success : AppColors.primary,
                          ),
                          child: const Text('Going'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}