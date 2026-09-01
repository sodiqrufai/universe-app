import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import '../widgets/step_progress_dots.dart';
import 'faculty_selector_screen.dart';

class University {
  final String id;
  final String name;
  final String? shortName;
  final String? city;

  University({required this.id, required this.name, this.shortName, this.city});

  factory University.fromJson(Map<String, dynamic> json) {
    return University(
      id: json['id'],
      name: json['name'],
      shortName: json['short_name'],
      city: json['city'],
    );
  }
}

class UniversitySelectorScreen extends StatefulWidget {
  const UniversitySelectorScreen({super.key});

  @override
  State<UniversitySelectorScreen> createState() =>
      _UniversitySelectorScreenState();
}

class _UniversitySelectorScreenState extends State<UniversitySelectorScreen> {
  List<University> _all = [];
  List<University> _filtered = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchUniversities();
  }

  Future<void> _fetchUniversities() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    // /universities returns a bare JSON array, unlike the rest of the
    // API's {success, ...} shape — ApiService assumes the latter, so
    // this one endpoint stays on raw http rather than risk a type
    // mismatch. Doesn't need auth, so no token handling needed either.
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/universities'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final universities = data.map((e) => University.fromJson(e)).toList();
        setState(() {
          _all = universities;
          _filtered = universities;
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

  void _search(String query) {
    setState(() {
      _filtered = _all
          .where((u) => u.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _select(University u) async {
    try {
      final data = await ApiService.patch('/profile/update', {'universityId': u.id});
      if (data['success'] == true) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => FacultySelectorScreen(universityId: u.id)),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to save university')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save your university')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your University')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepProgressDots(currentStep: 8, totalSteps: 12),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search your university...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load universities', onRetry: _fetchUniversities);
    }
    if (_filtered.isEmpty) {
      return const EmptyView(icon: Icons.school_outlined, title: 'No universities found');
    }
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final u = _filtered[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.school, color: Colors.white),
            ),
            title: Text(u.name),
            subtitle: Text([u.shortName, u.city].where((x) => x != null).join(' • ')),
            onTap: () => _select(u),
          ),
        );
      },
    );
  }
}
