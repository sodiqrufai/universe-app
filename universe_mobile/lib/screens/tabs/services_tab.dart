import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Services', style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
    );
  }
}