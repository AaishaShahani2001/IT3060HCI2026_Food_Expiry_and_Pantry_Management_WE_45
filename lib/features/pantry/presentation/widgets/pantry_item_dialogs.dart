import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

Future<bool> confirmDeletePantryItem(
  BuildContext context, {
  required String itemName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Delete item',
        style: TextStyle(color: AppColors.heading, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Are you sure you want to delete $itemName?',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.statusRed,
            minimumSize: const Size(88, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return confirmed == true;
}
