import 'package:flutter/material.dart';

/// Shows a short, non-persistent reloading-safety reminder once per app
/// launch via [showDialog]. The user must tap "I understand" to dismiss.
Future<void> showLaunchDisclaimer(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('Reminder'),
        content: SingleChildScrollView(
          child: Text(
            'Always verify recipe data against current manufacturer '
            'publications. LoadOut is reference information only — never '
            'your sole source. Reloading is dangerous; you accept all risk.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('I Understand'),
          ),
        ],
      );
    },
  );
}
