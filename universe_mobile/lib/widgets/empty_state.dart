import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A friendly, intentional "nothing here yet" state: a soft icon badge, a
/// clear title, one helpful sentence and (optionally) a button that takes
/// the user to the obvious next step.
///
/// Use [RefreshableEmptyState] when the empty state sits where a list would
/// be, so pull-to-refresh keeps working.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.add, size: 18),
              label: Text(actionLabel!),
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Wraps an empty state so it stays centred AND pull-to-refresh still works
/// (a plain Center would not be scrollable, so the gesture would do nothing).
class RefreshableEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const RefreshableEmptyState({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turns a failed ApiService result into a message a student understands.
/// ApiService (never throws) flags `networkError` and `rateLimited`; anything
/// else falls back to the screen's own wording.
String loadErrorMessage(Map<String, dynamic>? result, String fallback) {
  if (result == null) return fallback;
  if (result['networkError'] == true) {
    return "Can't reach UniVerse right now. Check your internet connection and try again.";
  }
  if (result['rateLimited'] == true) {
    return 'Too many requests. Please wait a few seconds and try again.';
  }
  return fallback;
}
