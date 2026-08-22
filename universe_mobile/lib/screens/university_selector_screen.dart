import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'faculty_selector_screen.dart';
// import 'home_screen.dart';
// import 'register_screen.dart';

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
  State<UniversitySelectorScreen> createState() => _UniversitySelectorScreenState();
}

class _UniversitySelectorScreenState extends State<UniversitySelectorScreen> {
  List<University> _all = [];
  List<University> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUniversities();
  }

  Future<void> _fetchUniversities() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/universities'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final list = data.map((e) => University.fromJson(e)).toList();
        setState(() {
          _all = list;
          _filtered = list;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your University')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search your university...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('No universities found'));
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
            onTap: () async {
              final token = await SessionService.getToken();
              try {
                final response = await http.patch(
                  Uri.parse('http://localhost:3000/profile/update'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({'universityId': u.id}),
                );
                final data = jsonDecode(response.body);
                if (data['success'] == true) {
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => FacultySelectorScreen(universityId: u.id)),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(data['error'] ?? 'Failed to save university')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}