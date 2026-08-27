import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/session_service.dart';
import '../anonymous_setup_screen.dart';
import '../anonymous_feed_screen.dart';
import '../marketplace_screen.dart';
import '../events_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback? onGoToEducation;
  const HomeTab({super.key, this.onGoToEducation});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<dynamic> _announcements = [];
  String? _universityName;
  String? _fullName;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchHome();
  }

  Future<void> _fetchHome() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/home'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _announcements = data['announcements'];
          _universityName = data['universityName'];
          _fullName = data['fullName'];
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _openAnonymous() async {
    final token = await SessionService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/anonymous/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    final hasProfile = data['success'] == true && data['profile'] != null;

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => hasProfile ? const AnonymousFeedScreen() : const AnonymousSetupScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: Colors.black38),
            const SizedBox(height: 12),
            const Text('Could not load your feed'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchHome, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHome,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_greeting()}, ${_fullName?.split(' ').first ?? 'there'} 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          if (_universityName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                _universityName!,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          _buildShortcuts(),
          const SizedBox(height: 24),
          const Text(
            'Announcements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          if (_announcements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No announcements yet — check back soon.')),
            )
          else
            ..._announcements.map((a) => _buildAnnouncementCard(a)),
        ],
      ),
    );
  }

  Widget _buildShortcuts() {
    final shortcuts = [
      {'icon': Icons.school_outlined, 'label': 'Education'},
      {'icon': Icons.storefront_outlined, 'label': 'Marketplace'},
      {'icon': Icons.masks_outlined, 'label': 'Anonymous'},
      {'icon': Icons.event_outlined, 'label': 'Events'},
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: shortcuts.map((s) {
        return GestureDetector(
          onTap: () {
            final label = s['label'];
            if (label == 'Anonymous') {
              _openAnonymous();
            } else if (label == 'Marketplace') {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketplaceScreen()));
            } else if (label == 'Events') {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventsScreen()));
            } else if (label == 'Education') {
              widget.onGoToEducation?.call();
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(s['icon'] as IconData, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(s['label'] as String, style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnnouncementCard(dynamic a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (a['is_global'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'UniVerse',
                      style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(a['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(a['body'], style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}