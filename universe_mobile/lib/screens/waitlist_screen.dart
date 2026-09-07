import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'university_selector_screen.dart';
import 'waitlist_holding_screen.dart';

/// Shown when the university a signing-up student picked isn't piloted
/// yet (University.isPilot == false). Distinct from
/// WaitlistHoldingScreen, which is for someone who already joined and
/// is just checking back in on a later app launch.
class WaitlistScreen extends StatefulWidget {
  final University university;
  const WaitlistScreen({super.key, required this.university});

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  bool _joining = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final data = await ApiService.post('/waitlist/join', {
        'universityId': widget.university.id,
      });
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WaitlistHoldingScreen(universityName: widget.university.name),
          ),
        );
      } else {
        setState(() {
          _joining = false;
          _error = data['error'] ?? 'Could not join the waitlist';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = 'Could not join the waitlist';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Waitlist')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'UniVerse isn\'t at ${widget.university.name} yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Join the waitlist and we\'ll notify you the moment we launch there.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              ),
            ElevatedButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Join Waitlist'),
            ),
          ],
        ),
      ),
    );
  }
}
