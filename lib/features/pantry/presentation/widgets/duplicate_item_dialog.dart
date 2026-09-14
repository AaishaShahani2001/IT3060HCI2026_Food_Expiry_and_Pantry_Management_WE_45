import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';

/// Result of the duplicate-item confirmation dialog.
enum DuplicateItemAction { cancel, addAnyway, updateExisting }

/// Customer-friendly confirmation when a pantry item name already exists.
Future<DuplicateItemAction?> showDuplicateItemDialog({
  required BuildContext context,
  required PantryItem existingItem,
}) {
  return showDialog<DuplicateItemAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DuplicateItemDialog(existingItem: existingItem),
  );
}

class DuplicateItemDialog extends StatelessWidget {
  const DuplicateItemDialog({required this.existingItem, super.key});

  final PantryItem existingItem;

  @override
  Widget build(BuildContext context) {
    final message =
        '${existingItem.name} is already in your ${existingItem.location.label}. '
        'Would you like to update its quantity instead?';

    return AlertDialog(
      backgroundColor: FreshPalette.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Item already exists',
        style: TextStyle(
          color: FreshPalette.heading,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: FreshPalette.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(DuplicateItemAction.updateExisting),
              style: FilledButton.styleFrom(
                backgroundColor: FreshPalette.primaryButton,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Update Existing'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(DuplicateItemAction.addAnyway),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: FreshPalette.heading,
              ),
              child: const Text('Add Anyway'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(DuplicateItemAction.cancel),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: FreshPalette.secondaryText,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
