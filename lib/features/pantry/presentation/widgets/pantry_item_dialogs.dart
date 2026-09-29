import 'package:flutter/material.dart';

Future<bool> confirmDeletePantryItem(
  BuildContext context, {
  required String itemName,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $itemName?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'This will permanently remove $itemName from your pantry.\n'
            'Use “Used Up” instead if you consumed it.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size(88, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  return confirmed == true;
}

/// Shown when decreasing quantity would go below zero.
/// Returns true to mark Used Up, false to keep the item.
Future<bool?> showNoQuantityRemainingDialog(
  BuildContext context, {
  required String itemName,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'No $itemName remaining?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Keep this item in your pantry, or mark it as used up if you finished it.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Keep Item'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Mark as Used Up'),
          ),
        ],
      );
    },
  );
}
