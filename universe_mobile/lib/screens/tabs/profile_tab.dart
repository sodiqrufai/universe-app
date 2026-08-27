import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/session_service.dart';
import '../edit_profile_screen.dart';
import '../login_screen.dart';
import '../settings_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profile/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _profile = data['profile'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await SessionService.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final isVerified = _profile?['is_verified'] == true;
    final avatarUrl = _profile?['avatar_url'];
    final fullName = _profile?['full_name'] ?? 'Student';
    final username = _profile?['username'];
    final bio = _profile?['bio'];
    final universityName = _profile?['universities']?['name'];
    final departmentName = _profile?['departments']?['name'];
    final level = _profile?['level'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fullName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppColors.primary, size: 20),
                        ],
                      ],
                    ),
                    if (username != null)
                      Text('@$username', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          if (bio != null && bio.toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(bio, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 20),
          if (universityName != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(universityName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (departmentName != null || level != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [departmentName, level].where((x) => x != null).join(' • '),
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              _fetchProfile();
            },
            child: const Text('Edit Profile'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}