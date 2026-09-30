import 'package:flutter/material.dart';

import '../../domain/models/pantry_item.dart';

/// Result of the duplicate-item confirmation dialog.
enum DuplicateItemAction { cancel, addAnyway, updateExisting }

/// Shopping uses Pantry's existing duplicate language and visual treatment,
/// but only needs an explicit Add Anyway / Cancel decision.
Future<bool> showPantryPresenceWarning({
  required BuildContext context,
  required PantryItem existingItem,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        backgroundColor: colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Already in your pantry'),
        content: Text(
          '${existingItem.name} is already in your pantry. '
          'Current quantity: ${existingItem.quantityLabel}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add Anyway'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

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
