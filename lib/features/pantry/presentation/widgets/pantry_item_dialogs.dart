import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

Future<bool> confirmDeletePantryItem(
  BuildContext context, {
  required String itemName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: FreshPalette.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $itemName?',
          style: const TextStyle(
            color: FreshPalette.heading,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'This will permanently remove $itemName from your pantry.\n'
            'Use “Used Up” instead if you consumed it.',
            style: const TextStyle(
              color: FreshPalette.secondaryText,
              height: 1.4,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: FreshPalette.secondaryText,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              foregroundColor: Colors.white,
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
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: FreshPalette.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'No $itemName remaining?',
          style: const TextStyle(
            color: FreshPalette.heading,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Keep this item in your pantry, or mark it as used up if you finished it.',
            style: TextStyle(color: FreshPalette.secondaryText, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: FreshPalette.secondaryText,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Keep Item'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: FreshPalette.primaryButton,
              foregroundColor: Colors.white,
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
