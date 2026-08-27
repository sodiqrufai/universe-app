import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'verification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _verification;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/verification/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _verification = data['verification'];
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

  Widget _statusSection() {
    if (_loading) return const SizedBox.shrink();

    final status = _verification?['status'];

    if (status == null) {
      return ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerificationScreen()),
          );
          if (result == true) _fetchStatus();
        },
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Get Verified'),
      );
    }

    if (status == 'pending') {
      return const Chip(
        avatar: Icon(Icons.circle, size: 12, color: Colors.orange),
        label: Text('Verification Pending'),
      );
    }

    if (status == 'approved') {
      return const Chip(
        avatar: Icon(Icons.circle, size: 12, color: AppColors.success),
        label: Text('Verified Student'),
      );
    }

    if (status == 'rejected') {
      return Column(
        children: [
          const Chip(
            avatar: Icon(Icons.circle, size: 12, color: Colors.red),
            label: Text('Verification Rejected'),
          ),
          if (_verification?['rejection_reason'] != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Reason: ${_verification!['rejection_reason']}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VerificationScreen()),
              );
              if (result == true) _fetchStatus();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Resubmit'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniVerse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome! Your profile is set up.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _statusSection(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
              child: const Text('Edit Profile'),
            ),
          ],
        ),
      ),
    );
  }
}