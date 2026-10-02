import 'package:flutter/material.dart';

Future<bool?> showStopTrackingDialog(
  BuildContext context, {
  required String itemName,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        title: Text('Stop tracking $itemName?'),
        content: Text(
          '$itemName will remain in your pantry, but its expiry date will no longer be tracked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop Tracking'),
          ),
        ],
      );
    },
  );
}
