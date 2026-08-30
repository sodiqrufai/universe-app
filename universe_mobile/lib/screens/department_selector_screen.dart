import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import 'main_shell.dart';

class DepartmentSelectorScreen extends StatefulWidget {
  final String facultyId;
  const DepartmentSelectorScreen({super.key, required this.facultyId});

  @override
  State<DepartmentSelectorScreen> createState() =>
      _DepartmentSelectorScreenState();
}

class _DepartmentSelectorScreenState extends State<DepartmentSelectorScreen> {
  List<dynamic> _departments = [];
  bool _loading = true;
  bool _hasError = false;
  String? _selectedDepartmentId;

  final List<String> _levels = ['100L', '200L', '300L', '400L', '500L'];

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    // Same bare-array response shape as /universities and /faculties —
    // stays on raw http rather than forcing it through ApiService's
    // {success} assumption.
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/departments?facultyId=${widget.facultyId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _departments = jsonDecode(response.body);
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

  Future<void> _selectDepartment(String departmentId) async {
    try {
      final data = await ApiService.patch('/profile/update', {'departmentId': departmentId});
      if (data['success'] == true) {
        setState(() => _selectedDepartmentId = departmentId);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to save department')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save your department')));
      }
    }
  }

  Future<void> _selectLevel(String level) async {
    try {
      final data = await ApiService.patch('/profile/update', {'level': level});
      if (data['success'] == true && mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to save your level')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save your level')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedDepartmentId == null ? 'Select Your Department' : 'Select Your Level',
        ),
      ),
      body: _loading
          ? const LoadingView()
          : _hasError
          ? ErrorView(message: 'Could not load departments', onRetry: _fetchDepartments)
          : _selectedDepartmentId == null
          ? _buildDepartmentList()
          : _buildLevelList(),
    );
  }

  Widget _buildDepartmentList() {
    if (_departments.isEmpty) {
      return const EmptyView(
        icon: Icons.corporate_fare_outlined,
        title: 'No departments found for this faculty yet',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
