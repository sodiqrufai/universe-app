import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared step indicator for the sign-up flow — a row of dots, the
/// current step wider and filled, completed steps filled, upcoming
/// steps hollow. One widget, used identically across every sign-up
/// screen rather than styled per-screen.
class StepProgressDots extends StatelessWidget {
  final int currentStep; // 1-based
  final int totalSteps;

  const StepProgressDots({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final step = i + 1;
        final isCurrent = step == currentStep;
        final isDone = step < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isCurrent ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: (isCurrent || isDone) ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}
