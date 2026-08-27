import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'department_selector_screen.dart';

class FacultySelectorScreen extends StatefulWidget {
  final String universityId;
  const FacultySelectorScreen({super.key, required this.universityId});

  @override
  State<FacultySelectorScreen> createState() => _FacultySelectorScreenState();
}

class _FacultySelectorScreenState extends State<FacultySelectorScreen> {
  List<dynamic> _faculties = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFaculties();
  }

  Future<void> _fetchFaculties() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/faculties?universityId=${widget.universityId}'),
      );
      setState(() {
        _faculties = jsonDecode(response.body);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load faculties: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectFaculty(String facultyId, String facultyName) async {
    final token = await SessionService.getToken();
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'facultyId': facultyId}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DepartmentSelectorScreen(facultyId: facultyId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Faculty')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _faculties.isEmpty
                  ? const Center(child: Text('No faculties found for this university yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _faculties.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final f = _faculties[index];
                        return Card(
                          child: ListTile(
                            title: Text(f['name']),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectFaculty(f['id'], f['name']),
                          ),
                        );
                      },
                    ),
    );
  }
}