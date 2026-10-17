import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/create_post_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/tabs/explore_tab.dart';
import '../screens/tabs/messages_tab.dart';
import '../screens/verification_status_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// Where the student is on the "Get started" list. Pure data + logic, so it
/// can be unit-tested without any UI or network.
class ChecklistProgress {
  final bool profileDone;
  final bool verified;
  final bool posted;
  final bool explored;
  final bool messaged;

  const ChecklistProgress({
    this.profileDone = false,
    this.verified = false,
    this.posted = false,
    this.explored = false,
    this.messaged = false,
  });

  static const int total = 5;

  int get done =>
      [profileDone, verified, posted, explored, messaged].where((d) => d).length;
  bool get allDone => done == total;
  double get fraction => done / total;

  /// Builds progress from what the app already knows how to ask the backend:
  /// `/profile/me` (profile), `/profile/my-posts`, `/chat/inbox`, plus a
  /// local "has opened Explore" flag.
  factory ChecklistProgress.fromData({
    Map<String, dynamic>? profile,
    int postCount = 0,
    int conversationCount = 0,
    bool explored = false,
  }) {
    final avatar = (profile?['avatar_url'] ?? '').toString().trim();
    final bio = (profile?['bio'] ?? '').toString().trim();
    return ChecklistProgress(
      profileDone: avatar.isNotEmpty && bio.isNotEmpty,
      verified: profile?['is_verified'] == true,
      posted: postCount > 0,
      explored: explored,
      messaged: conversationCount > 0,
    );
  }
}

/// Remembers, per account on this device, whether the checklist was hidden
/// and whether Explore has been opened. Keyed by user id so two people
/// sharing a phone don't affect each other.
class ChecklistStore {
  ChecklistStore._();

  static String _dismissedKey(String uid) => 'checklist_dismissed_$uid';
  static String _exploredKey(String uid) => 'checklist_explored_$uid';

  static Future<bool> isDismissed(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey(uid)) ?? false;
  }

  static Future<void> dismiss(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey(uid), true);
  }

  static Future<bool> isExplored(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_exploredKey(uid)) ?? false;
  }

  static Future<void> markExplored(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_exploredKey(uid), true);
  }
}

/// Dismissible "Get started" card shown at the top of the Feed. Ticks items
/// off from real account state, hides itself if it can't tell the truth
/// (offline / error), and never blocks the feed from loading.
class WelcomeChecklist extends StatefulWidget {
  /// Called when something done from the checklist changes the feed itself
  /// (e.g. the first post), so the Feed can reload.
  final VoidCallback? onFeedChanged;

  const WelcomeChecklist({super.key, this.onFeedChanged});

  @override
  State<WelcomeChecklist> createState() => WelcomeChecklistState();
}

class WelcomeChecklistState extends State<WelcomeChecklist> {
  String? _uid;
  bool _dismissed = false;
  ChecklistProgress? _progress; // null = not loaded yet, or couldn't load

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// Re-reads account state. The Feed calls this on pull-to-refresh.
  Future<void> refresh() async {
    final uid = _uid ?? await SessionService.getUserId();
    if (uid == null || !mounted) return;
    _uid = uid;

    if (await ChecklistStore.isDismissed(uid)) {
      if (mounted) setState(() => _dismissed = true);
      return;
    }

    // Start all three requests first so they run in parallel.
    final profileFuture = ApiService.get('/profile/me');
    final postsFuture = ApiService.get('/profile/my-posts');
    final inboxFuture = ApiService.get('/chat/inbox');
    final profileRes = await profileFuture;
    final postsRes = await postsFuture;
    final inboxRes = await inboxFuture;
    final explored = await ChecklistStore.isExplored(uid);
    if (!mounted) return;

    // Without the profile we can't tell what's done, and a wrong checklist is
    // worse than none. Hide quietly; the next refresh tries again.
    final rawProfile = profileRes['profile'];
    if (profileRes['success'] != true || rawProfile is! Map) {
      setState(() => _progress = null);
      return;
    }

    int countOf(Map<String, dynamic> res, String key) {
      if (res['success'] != true) return 0;
      final list = res[key];
      return list is List ? list.length : 0;
    }

    setState(() {
      _progress = ChecklistProgress.fromData(
        profile: Map<String, dynamic>.from(rawProfile),
        postCount: countOf(postsRes, 'posts'),
        conversationCount: countOf(inboxRes, 'conversations'),
        explored: explored,
      );
    });
  }

  Future<void> _dismiss() async {
    final uid = _uid;
    if (uid != null) await ChecklistStore.dismiss(uid);
    if (mounted) setState(() => _dismissed = true);
  }

  Future<void> _open(Widget screen, {bool feedMayChange = false}) async {
    final navigator = Navigator.of(context);
    final result = await navigator.push<dynamic>(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    if (feedMayChange && result == true) widget.onFeedChanged?.call();
    refresh();
  }

  Widget _fullScreen(String title, Widget body) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: body);

  Future<void> _openExplore() async {
    final uid = _uid;
    if (uid != null) await ChecklistStore.markExplored(uid);
    if (!mounted) return;
    await _open(_fullScreen('Explore', const ExploreTab()));
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (_dismissed || progress == null) return const SizedBox.shrink();

    final items = <_ChecklistItem>[
      _ChecklistItem(
        title: 'Complete your profile',
        subtitle: 'Add a photo and a short bio',
        done: progress.profileDone,
        onTap: () => _open(const EditProfileScreen()),
      ),
      _ChecklistItem(
        title: 'Get verified',
        subtitle: 'Upload your student ID so people know you are real',
        done: progress.verified,
        onTap: () => _open(const VerificationStatusScreen()),
      ),
      _ChecklistItem(
        title: 'Make your first post',
        subtitle: 'Say hello to your campus',
        done: progress.posted,
        onTap: () => _open(const CreatePostScreen(), feedMayChange: true),
      ),
      _ChecklistItem(
        title: 'Explore the marketplace and events',
        subtitle: 'See what other students are offering',
        done: progress.explored,
        onTap: _openExplore,
      ),
      _ChecklistItem(
        title: 'Send a message',
        subtitle: 'Chat with a seller, a provider or a classmate',
        done: progress.messaged,
        onTap: () => _open(_fullScreen('Messages', const MessagesTab())),
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightPurple,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  progress.allDone
                      ? Icons.celebration_outlined
                      : Icons.rocket_launch_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.allDone
                          ? "You're all set"
                          : 'Get started with UniVerse',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      progress.allDone
                          ? 'Nice work, you have done everything on the list.'
                          : '${progress.done} of ${ChecklistProgress.total} done',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hide this list',
                icon: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
                onPressed: _dismiss,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              backgroundColor: AppColors.lightPurple,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          if (progress.allDone) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _dismiss, child: const Text('Dismiss')),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            for (final item in items) _row(item),
          ],
        ],
      ),
    );
  }

  Widget _row(_ChecklistItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              item.done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: item.done ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.done
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.done)
              Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem {
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });
}
