import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_info.dart';
import '../services/telemetry.dart';
import '../theme/app_theme.dart';

/// Maps a /feedback API result to a message a student can understand.
/// Public so it can be unit-tested.
String feedbackErrorMessage(Map<String, dynamic>? result) {
  if (result == null) return 'Could not send your feedback. Please try again.';
  if (result['networkError'] == true || result['timedOut'] == true) {
    return 'No connection. Check your internet and try again. Your message is still here.';
  }
  if (result['rateLimited'] == true || result['statusCode'] == 429) {
    return 'You are sending feedback too fast. Please wait a minute and try again.';
  }
  final err = result['error'];
  if (err is String && err.trim().isNotEmpty) return err;
  return 'Could not send your feedback. Please try again.';
}

/// Settings -> Send feedback. Posts to POST /feedback (auth optional,
/// 3-2000 chars, throttled server-side).
class FeedbackScreen extends StatefulWidget {
  /// Name of the screen the person came from; sent along to help debugging.
  final String screenName;
  const FeedbackScreen({super.key, this.screenName = 'Settings'});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const int _minLength = 3;
  static const int _maxLength = 2000;
  static const _categories = [
    ('bug', 'Bug', Icons.bug_report_outlined),
    ('idea', 'Idea', Icons.lightbulb_outline),
    ('other', 'Other', Icons.chat_bubble_outline),
  ];

  final _controller = TextEditingController();
  String _category = 'bug';
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending && _controller.text.trim().length >= _minLength;

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.length < _minLength) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    Map<String, dynamic> result;
    try {
      result = await ApiService.post('/feedback', {
        'message': message,
        'category': _category,
        'screen': widget.screenName,
        'appVersion': AppInfo.version,
        'platform': AppInfo.platform,
      });
    } catch (_) {
      result = {'success': false, 'networkError': true};
    }
    if (!mounted) return;
    if (result['success'] == true) {
      Telemetry.track('feedback_sent', {'category': _category});
      setState(() {
        _sending = false;
        _sent = true;
      });
    } else {
      setState(() {
        _sending = false;
        _error = feedbackErrorMessage(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: SafeArea(child: _sent ? _buildThanks() : _buildForm()),
    );
  }

  Widget _buildThanks() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Thank you!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We read every message. Your feedback helps make UniVerse better for every student.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final length = _controller.text.length;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'What is this about?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final c in _categories)
              ChoiceChip(
                avatar: Icon(c.$3, size: 18),
                label: Text(c.$2),
                selected: _category == c.$1,
                onSelected: _sending ? null : (_) => setState(() => _category = c.$1),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          enabled: !_sending,
          maxLines: 8,
          minLines: 5,
          maxLength: _maxLength,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _category == 'bug'
                ? 'What happened? What did you expect?'
                : _category == 'idea'
                    ? 'What would make UniVerse better for you?'
                    : 'Tell us anything',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            counterText: '$length / $_maxLength',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: _canSend ? _send : null,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'We include your app version (${AppInfo.version}) and device type (${AppInfo.platform}) to help us fix things faster.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
