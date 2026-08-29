import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
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
  bool _hasError = false;
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
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.get('/events/${widget.eventId}');
      if (data['event'] != null) {
        setState(() {
          _event = data['event'];
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

  Future<void> _rsvp(String status) async {
    try {
      final data = await ApiService.post('/events/${widget.eventId}/rsvp', {
        'status': status,
      });
      if (data['success'] == true) {
        _fetchEvent();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'going' ? "You're going!" : 'Marked as interested'),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not RSVP')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not RSVP')));
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
        title: const Text('Report this event'),
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
        final data = await ApiService.post('/events/${widget.eventId}/report', {
          'reason': reason,
        });
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

  Future<void> _cancelEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Cancel this event?'),
        content: const Text('Everyone who RSVPed will see it as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final data = await ApiService.patch('/events/${widget.eventId}/cancel', {});
        if (data['success'] == true) {
          _fetchEvent();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not cancel event')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not cancel event')),
          );
        }
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
    if (_hasError || _event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('Could not load this event'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchEvent, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final startsAt = DateTime.tryParse(_event!['starts_at'] ?? '');
    final dateLabel = startsAt != null
        ? DateFormat('EEEE, MMM d • h:mm a').format(startsAt.toLocal())
        : '';
    final profile = _event!['profiles'];
    final isMine = _event!['organizer_id'] == _myUserId;
    final isCancelled = _event!['status'] == 'cancelled';
    final myRsvp = _event!['myRsvp'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          if (!isMine)
            IconButton(icon: const Icon(Icons.flag_outlined), onPressed: _report),
          if (isMine && !isCancelled)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
              onPressed: _cancelEvent,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_event!['cover_image_url'] != null)
            Image.network(
              _event!['cover_image_url'],
              height: 220,
              fit: BoxFit.cover,
              width: double.infinity,
            )
          else
            Container(
              height: 220,
              color: AppColors.lightPurple,
              child: const Icon(Icons.event, size: 60, color: AppColors.primary),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCancelled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text(
                      'Cancelled',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  _event!['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(dateLabel, style: const TextStyle(color: AppColors.textSecondary)),
                if (_event!['location'] != null)
                  Text(
                    _event!['location'],
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${_event!['goingCount'] ?? 0} going • ${_event!['interestedCount'] ?? 0} interested',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_event!['description'] != null)
                  Text(
                    _event!['description'],
                    style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                  ),
                const SizedBox(height: AppSpacing.lg),
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
                        radius: 16,
                        backgroundColor: AppColors.lightPurple,
                        backgroundImage: profile?['avatar_url'] != null
                            ? NetworkImage(profile['avatar_url'])
                            : null,
                        child: profile?['avatar_url'] == null
                            ? const Icon(Icons.person, size: 16, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Organized by ${profile?['full_name'] ?? 'Someone'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (!isCancelled)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rsvp('interested'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: myRsvp == 'interested'
                                ? AppColors.lightPurple
                                : null,
                          ),
                          child: const Text('Interested'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _rsvp('going'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: myRsvp == 'going'
                                ? AppColors.success
                                : AppColors.primary,
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
