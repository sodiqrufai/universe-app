import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dedicated dialog for a suspended/restricted account trying to post,
/// comment, react, RSVP, etc. — deliberately a modal, not a snackbar,
/// since this is the kind of thing a student shouldn't be able to miss
/// or mistake for a generic network error.
Future<void> showRestrictedDialog(BuildContext context, String message) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      icon: const Icon(Icons.block, color: AppColors.error, size: 32),
      title: const Text('Action Restricted'),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Understood'),
        ),
      ],
    ),
  );
}
