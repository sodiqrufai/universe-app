import '../../../config/api_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/session_service.dart';
import '../course_detail_screen.dart';

class EducationTab extends StatefulWidget {
  const EducationTab({super.key});

  @override
  State<EducationTab> createState() => _EducationTabState();
}

class _EducationTabState extends State<EducationTab> {
  List<dynamic> _courses = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/education/courses'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _courses = data['courses'];
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: Colors.black38),
            const SizedBox(height: 12),
            const Text('Could not load your courses'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchCourses,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_courses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No courses found for your department yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCourses,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final course = _courses[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: Text(course['name']),
              subtitle: course['code'] != null ? Text(course['code']) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(course: course),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

