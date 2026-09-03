import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import '../widgets/step_progress_dots.dart';
import '../models/profile_setup_data.dart';
import 'department_selector_screen.dart';

class FacultySelectorScreen extends StatefulWidget {
  final String universityId;
  final ProfileSetupData setupData;
  final bool editMode;
  const FacultySelectorScreen({
    super.key,
    required this.universityId,
    this.setupData = const ProfileSetupData(),
    this.editMode = false,
  });

  @override
  State<FacultySelectorScreen> createState() => _FacultySelectorScreenState();
}

class _FacultySelectorScreenState extends State<FacultySelectorScreen> {
  List<dynamic> _faculties = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchFaculties();
  }

  Future<void> _fetchFaculties() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    // Same bare-array response shape as /universities — stays on raw
    // http rather than forcing it through ApiService's {success} assumption.
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/faculties?universityId=${widget.universityId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _faculties = jsonDecode(response.body);
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

  Future<void> _selectFaculty(String facultyId) async {
    try {
      final data = await ApiService.patch('/profile/update', {'facultyId': facultyId});
      if (data['success'] == true && mounted) {
        // NOTE: same caveat as UniversitySelectorScreen — department_id
        // isn't reset here and can be left pointing at the previous
        // faculty's hierarchy until Department is also re-picked.
        if (widget.editMode) {
          Navigator.of(context).pop(true);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DepartmentSelectorScreen(facultyId: facultyId, setupData: widget.setupData),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not save your faculty')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save your faculty')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editMode ? 'Edit Faculty' : 'Select Your Faculty')),
      body: Column(
        children: [
          if (!widget.editMode)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: StepProgressDots(currentStep: 9, totalSteps: 12),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_hasError) {
      return ErrorView(message: 'Could not load faculties', onRetry: _fetchFaculties);
    }
    if (_faculties.isEmpty) {
      return const EmptyView(
        icon: Icons.account_balance_outlined,
        title: 'No faculties found for this university yet',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _faculties.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final f = _faculties[index];
        return Card(
          child: ListTile(
            title: Text(f['name']),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectFaculty(f['id']),
          ),
        );
      },
    );
  }
}
