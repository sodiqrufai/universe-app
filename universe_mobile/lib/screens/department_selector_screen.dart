import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import '../widgets/step_progress_dots.dart';
import '../models/profile_setup_data.dart';
import 'level_selector_screen.dart';

/// Step 10 of 12: Department. Level selection used to be a second phase
/// of this same screen — split out into its own screen (level_selector_
/// screen.dart) so each step in the sign-up flow gets its own dot.
class DepartmentSelectorScreen extends StatefulWidget {
  final String facultyId;
  final ProfileSetupData setupData;
  const DepartmentSelectorScreen({
    super.key,
    required this.facultyId,
    this.setupData = const ProfileSetupData(),
  });

  @override
  State<DepartmentSelectorScreen> createState() =>
      _DepartmentSelectorScreenState();
}

class _DepartmentSelectorScreenState extends State<DepartmentSelectorScreen> {
  List<dynamic> _departments = [];
  bool _loading = true;
  bool _hasError = false;

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
      if (data['success'] == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LevelSelectorScreen(setupData: widget.setupData)),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Department')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: StepProgressDots(currentStep: 10, totalSteps: 12),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load departments', onRetry: _fetchDepartments);
    }
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
}
