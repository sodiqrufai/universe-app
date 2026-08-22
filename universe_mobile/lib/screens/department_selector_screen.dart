import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'main_shell.dart';

class DepartmentSelectorScreen extends StatefulWidget {
  final String facultyId;
  const DepartmentSelectorScreen({super.key, required this.facultyId});

  @override
  State<DepartmentSelectorScreen> createState() => _DepartmentSelectorScreenState();
}

class _DepartmentSelectorScreenState extends State<DepartmentSelectorScreen> {
  List<dynamic> _departments = [];
  bool _loading = true;
  String? _error;
  String? _selectedDepartmentId;

  final List<String> _levels = ['100L', '200L', '300L', '400L', '500L'];

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/departments?facultyId=${widget.facultyId}'),
      );
      setState(() {
        _departments = jsonDecode(response.body);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load departments: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectDepartment(String departmentId) async {
    setState(() {
      _selectedDepartmentId = departmentId;
    });

    final token = await SessionService.getToken();
    try {
      final response = await http.patch(
        Uri.parse('http://localhost:3000/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'departmentId': departmentId}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to save department')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _selectLevel(String level) async {
    final token = await SessionService.getToken();
    try {
      final response = await http.patch(
        Uri.parse('http://localhost:3000/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'level': level}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
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
      appBar: AppBar(
        title: Text(_selectedDepartmentId == null ? 'Select Your Department' : 'Select Your Level'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _selectedDepartmentId == null
                  ? _buildDepartmentList()
                  : _buildLevelList(),
    );
  }

  Widget _buildDepartmentList() {
    if (_departments.isEmpty) {
      return const Center(child: Text('No departments found for this faculty yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _departments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = _departments[index];
        return Card(
          child: ListTile(
            title: Text(d['name']),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectDepartment(d['id']),
          ),
        );
      },
    );
  }

  Widget _buildLevelList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _levels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final level = _levels[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.school_outlined, color: AppColors.primary),
            title: Text(level),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectLevel(level),
          ),
        );
      },
    );
  }
}