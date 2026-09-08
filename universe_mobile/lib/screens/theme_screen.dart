import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  final _options = const [
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
    (ThemeMode.system, 'System default', Icons.smartphone_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final current = ThemeController.instance.mode;
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final (mode, label, icon) = _options[i];
          final selected = mode == current;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () async {
              await ThemeController.instance.setMode(mode);
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.lightPurple, shape: BoxShape.circle),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  ),
                  if (selected) Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
