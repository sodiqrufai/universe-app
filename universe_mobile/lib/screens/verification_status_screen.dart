import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import 'verification_screen.dart';

/// Entry point for "Account Verification". Fetches the student's current
/// verification state and shows the right view for it:
///   - never submitted -> the submission form (VerificationScreen) directly
///   - pending -> a simple "under review" holding view
///   - approved -> a summary of what was submitted
///   - rejected -> the rejection reason + a button to reupload
class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  bool _loading = true;
  bool _hasError = false;
  Map<String, dynamic>? _verification;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  bool _refreshing = false;

  Future<void> _fetchStatus({bool quiet = false}) async {
    if (quiet) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    final data = await ApiService.get('/verification/status');
    if (!mounted) return;
    if (data['success'] == true) {
      final v = data['verification'];
      setState(() {
        _verification = v is Map ? Map<String, dynamic>.from(v) : null;
        _loading = false;
        _hasError = false;
        _refreshing = false;
      });
    } else if (quiet) {
      // Keep showing what we had; just say the refresh failed.
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((data['error'] ?? "Couldn't refresh. Please try again.").toString())),
      );
    } else {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  String? _submittedOn() {
    final raw = _verification?['created_at'] ?? _verification?['updated_at'];
    if (raw is! String) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return null;
    return DateFormat('d MMM yyyy').format(d.toLocal());
  }

  Future<void> _openReupload() async {
    final resubmitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VerificationScreen(isReupload: true)),
    );
    if (resubmitted == true) {
      _fetchStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Verification')),
        body: const LoadingView(),
      );
    }
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Verification')),
        body: ErrorView(message: 'Could not load your verification status', onRetry: _fetchStatus),
      );
    }
    // Never submitted at all -- go straight to the submission form as its
    // own full screen (it has its own Scaffold/AppBar), not nested inside
    // this screen's -- rather than showing an empty state in between.
    if (_verification == null) {
      return VerificationScreen(
        onSubmitted: () {
          if (mounted) _fetchStatus();
        },
      );
    }

    final status = _verification!['status'] as String? ?? 'pending';
    return Scaffold(
      appBar: AppBar(title: const Text('Account Verification')),
      body: switch (status) {
        'approved' => _buildApproved(),
        'rejected' => _buildRejected(),
        _ => _buildPending(),
      },
    );
  }

  Widget _step(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPending() {
    final date = _submittedOn();
    return RefreshIndicator(
      onRefresh: () => _fetchStatus(quiet: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 24),
          Icon(Icons.hourglass_top_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Under review',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            date == null
                ? 'Your student ID has been submitted.'
                : 'Your student ID was submitted on $date.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _step(Icons.schedule, 'Reviews usually take 1 to 2 working days.'),
          _step(Icons.visibility_outlined, 'A person at UniVerse checks your name, matric number and ID photo.'),
          _step(Icons.verified_outlined, 'When it is approved you get the verified badge and full access. You can leave the app; nothing more is needed from you.'),
          _step(Icons.refresh, 'If something is unclear we will ask you to send a clearer photo, and you will see that here.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _refreshing ? null : () => _fetchStatus(quiet: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_refreshing ? 'Checking…' : 'Check status'),
          ),
        ],
      ),
    );
  }

  Widget _buildApproved() {
    final v = _verification!;
    final rows = <(IconData, String, String?)>[
      (Icons.badge_outlined, 'Name', v['full_name']),
      (Icons.confirmation_number_outlined, 'Matric Number', v['matric_number']),
      (Icons.school_outlined, 'University', v['universityName']),
      (Icons.apartment_outlined, 'Department', v['departmentName']),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Column(
            children: [
              Icon(Icons.verified, size: 56, color: AppColors.success),
              const SizedBox(height: 16),
              Text(
                'Verified Student',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Your account has full access.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                _infoRow(rows[i].$1, rows[i].$2, rows[i].$3),
                if (i != rows.length - 1) Divider(height: 1, indent: 56, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value ?? '—',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejected() {
    final reason = _verification!['rejection_reason'] as String?;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 24),
            Text(
              'Verification rejected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            if (reason != null && reason.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              )
            else
              const SizedBox(height: 24),
            Text(
              'You can send a new photo straight away. Make sure your name and matric number are clear and the whole card is in the frame. It will be reviewed again, usually within 1 to 2 working days.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openReupload,
              child: const Text('Reupload Document'),
            ),
          ],
        ),
      ),
    );
  }
}
