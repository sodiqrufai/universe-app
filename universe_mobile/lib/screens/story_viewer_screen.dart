import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// Full-screen story viewer. [authors] is the same grouped list the
/// carousel got from GET /stories (each author's `stories` list already
/// carries a `viewed` flag from the backend); [startIndex] is which
/// author to open first.
class StoryViewerScreen extends StatefulWidget {
  final List<dynamic> authors;
  final int startIndex;

  const StoryViewerScreen({
    super.key,
    required this.authors,
    required this.startIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late int _authorIndex;
  int _storyIndex = 0;
  double _progress = 0;
  String? _myUserId;

  AnimationController? _imageTimer;
  VideoPlayerController? _videoController;
  Timer? _videoProgressTimer;

  static const _imageDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _authorIndex = widget.startIndex;
    _pageController = PageController(initialPage: _authorIndex);
    _init();
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    _loadStory();
  }

  dynamic get _currentAuthor => widget.authors[_authorIndex];
  List<dynamic> get _currentStories =>
      (_currentAuthor['stories'] as List<dynamic>?) ?? [];
  dynamic get _currentStory =>
      _storyIndex < _currentStories.length ? _currentStories[_storyIndex] : null;

  void _clearMedia() {
    _imageTimer?.dispose();
    _imageTimer = null;
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    _videoController?.dispose();
    _videoController = null;
  }

  void _loadStory() {
    _clearMedia();
    final story = _currentStory;
    if (story == null) {
      // Ran out of stories for this author — treated by _advance().
      return;
    }
    setState(() => _progress = 0);
    _markViewed(story['id']);

    if (story['media_type'] == 'video') {
      _startVideo(story['media_url']);
    } else {
      _startImageTimer();
    }
  }

  Future<void> _markViewed(String storyId) async {
    // Passive telemetry — a failed view-ping shouldn't interrupt viewing,
    // so this is deliberately fire-and-forget with no user-facing error.
    try {
      await ApiService.post('/stories/$storyId/view', {});
    } catch (_) {}
  }

  void _startImageTimer() {
    _imageTimer = AnimationController(vsync: this, duration: _imageDuration)
      ..addListener(() {
        if (mounted) setState(() => _progress = _imageTimer!.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      })
      ..forward();
  }

  Future<void> _startVideo(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.play();
      _videoProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || controller.value.duration.inMilliseconds == 0) return;
        final p = controller.value.position.inMilliseconds /
            controller.value.duration.inMilliseconds;
        setState(() => _progress = p.clamp(0, 1));
        if (controller.value.position >= controller.value.duration) _advance();
      });
      setState(() {});
    } catch (_) {
      // Couldn't load the video — don't strand the viewer, just move on.
      _advance();
    }
  }

  void _advance() {
    if (_storyIndex < _currentStories.length - 1) {
      setState(() => _storyIndex++);
      _loadStory();
    } else if (_authorIndex < widget.authors.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _clearMedia();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _goBack() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _loadStory();
    } else if (_authorIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _onAuthorPageChanged(int index) {
    setState(() {
      _authorIndex = index;
      _storyIndex = 0;
    });
    _loadStory();
  }

  Future<void> _deleteStory(String storyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete this story?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final data = await ApiService.delete('/stories/$storyId');
        if (data['success'] == true) {
          _advance();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not delete story')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete story')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _clearMedia();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.of(context).pop();
          }
        },
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onAuthorPageChanged,
          itemCount: widget.authors.length,
          itemBuilder: (context, authorIdx) {
            // Only render tap zones/media for the active page; other
            // pages just reserve their slot in the PageView.
            if (authorIdx != _authorIndex) return const SizedBox.shrink();
            return _buildStoryPage();
          },
        ),
      ),
    );
  }

  Widget _buildStoryPage() {
    final story = _currentStory;
    if (story == null) return const SizedBox.shrink();
    final isMine = _currentAuthor['authorId'] == _myUserId;
    final profile = _currentAuthor['profile'];

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMedia(story),
        // Left/right tap zones for back/forward.
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _goBack,
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _advance,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ],
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: List.generate(_currentStories.length, (i) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: i < _storyIndex
                              ? 1
                              : (i == _storyIndex ? _progress : 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      backgroundImage: profile?['avatar_url'] != null
                          ? NetworkImage(profile['avatar_url'])
                          : null,
                      child: profile?['avatar_url'] == null
                          ? const Icon(Icons.person, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        profile?['full_name'] ?? 'Student',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isMine)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        tooltip: 'Delete story',
                        onPressed: () => _deleteStory(story['id']),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (story['caption'] != null && (story['caption'] as String).isNotEmpty)
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 32,
            child: Text(
              story['caption'],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildMedia(dynamic story) {
    if (story['media_type'] == 'video') {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: story['media_url'],
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 60),
      ),
    );
  }
}
