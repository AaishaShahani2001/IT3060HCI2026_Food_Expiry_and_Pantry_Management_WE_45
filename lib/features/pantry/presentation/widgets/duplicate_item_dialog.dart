import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final message =
        '${existingItem.name} is already in your ${existingItem.location.label}. '
        'Would you like to update its quantity instead?';

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerHighest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Item already exists',
        style: TextStyle(
          color: colorScheme.onSurface,
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
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(DuplicateItemAction.updateExisting),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
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
                foregroundColor: colorScheme.onSurface,
              ),
              child: const Text('Add Anyway'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(DuplicateItemAction.cancel),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
