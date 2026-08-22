import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class EducationTab extends StatelessWidget {
  const EducationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Education', style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
    );
  }
}