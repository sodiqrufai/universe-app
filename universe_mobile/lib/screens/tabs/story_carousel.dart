import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../story_viewer_screen.dart';

/// Horizontal story carousel shown above the Feed post list.
/// "Your Story" is always first; other authors follow, ring color
/// signaling whether they have an unviewed story.
class StoryCarousel extends StatefulWidget {
  const StoryCarousel({super.key});

  @override
  State<StoryCarousel> createState() => StoryCarouselState();
}

class StoryCarouselState extends State<StoryCarousel> {
  List<dynamic> _authors = [];
  bool _loading = true;
  String? _myUserId;
  String? _myAvatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    await refresh();
  }

  /// Public so FeedTab's pull-to-refresh can refresh stories too.
  Future<void> refresh() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/stories');
      if (data['success'] == true) {
        final authors = data['authors'] as List<dynamic>? ?? [];
        final mine = authors.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a?['authorId'] == _myUserId,
          orElse: () => null,
        );
        setState(() {
          _authors = authors.where((a) => a['authorId'] != _myUserId).toList();
          _myAvatarUrl = mine?['profile']?['avatar_url'];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStory() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final picker = ImagePicker();
    final picked = choice == 'video'
        ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30))
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final token = await SessionService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/stories'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['mediaType'] = choice;
      request.files.add(await http.MultipartFile.fromPath('file', picked.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        await refresh();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Story posted')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not post story')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not post story')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openViewer(int startIndex) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(authors: _authors, startIndex: startIndex),
      ),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 92,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _authors.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _buildYourStory();
          final author = _authors[i - 1];
          return _buildAuthorStory(author, i - 1);
        },
      ),
    );
  }

  Widget _buildYourStory() {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: _uploading ? null : _addStory,
        child: Column(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.lightPurple,
                    backgroundImage: _myAvatarUrl != null ? NetworkImage(_myAvatarUrl!) : null,
                    child: _myAvatarUrl == null
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: _uploading
                          ? const Padding(
                              padding: EdgeInsets.all(3),
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('Your Story', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorStory(dynamic author, int index) {
    final profile = author['profile'];
    final hasUnviewed = author['hasUnviewed'] == true;
    final name = (profile?['full_name'] ?? 'Student').toString().split(' ').first;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: () => _openViewer(index),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnviewed
                    ? const LinearGradient(colors: [AppColors.primary, AppColors.secondary])
                    : null,
                color: hasUnviewed ? null : AppColors.border,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.lightPurple,
                  backgroundImage: profile?['avatar_url'] != null
                      ? NetworkImage(profile['avatar_url'])
                      : null,
                  child: profile?['avatar_url'] == null
                      ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
