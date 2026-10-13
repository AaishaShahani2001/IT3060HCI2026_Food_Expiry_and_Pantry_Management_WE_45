import 'package:flutter/material.dart';

import '../../domain/models/pantry_item.dart';
import '../../domain/utils/pantry_expiry_batch.dart';

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

/// Asks which existing batch to use when several are equally relevant.
Future<PantryItem?> showPantryBatchPicker({
  required BuildContext context,
  required List<PantryItem> matches,
}) {
  return showDialog<PantryItem>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        backgroundColor: colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Which batch?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in matches)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(item),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${item.name}\n${pantryBatchSummary(item)}'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

Future<DuplicateItemAction?> showPantryDuplicateDialog({
  required BuildContext context,
  required PantryItem existing,
  required PantryItem candidate,
  required bool exactBatch,
}) {
  return showDialog<DuplicateItemAction>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => exactBatch
        ? ExactBatchDialog(existing: existing)
        : DifferentBatchDialog(existing: existing, candidate: candidate),
  );
}

class ExactBatchDialog extends StatelessWidget {
  const ExactBatchDialog({required this.existing, super.key});

  final PantryItem existing;

  @override
  Widget build(BuildContext context) {
    final message =
        '${existing.name} is already in your ${existing.location.label} '
        'with the same expiry date.\n\n'
        'Would you like to update the existing batch or add another entry?';

    return _BatchDialogShell(
      title: 'Item already exists',
      message: message,
      primaryLabel: 'Update Existing Batch',
      primaryAction: DuplicateItemAction.updateExisting,
      secondaryLabel: 'Add Separately',
      secondaryAction: DuplicateItemAction.addSeparately,
    );
  }
}

class DifferentBatchDialog extends StatelessWidget {
  const DifferentBatchDialog({
    required this.existing,
    required this.candidate,
    super.key,
  });

  final PantryItem existing;
  final PantryItem candidate;

  @override
  Widget build(BuildContext context) {
    final message =
        '${existing.name} already exists in your pantry\n\n'
        'Existing batch:\n${pantryBatchSummary(existing)}\n\n'
        'New batch:\n${pantryBatchSummary(candidate)}\n\n'
        'These appear to be different batches. Add this as a new batch?';

    return _BatchDialogShell(
      title: 'Different batch',
      message: message,
      primaryLabel: 'Add New Batch',
      primaryAction: DuplicateItemAction.addSeparately,
      secondaryLabel: 'View Existing',
      secondaryAction: DuplicateItemAction.viewExisting,
    );
  }
}

class _BatchDialogShell extends StatelessWidget {
  const _BatchDialogShell({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryAction,
    required this.secondaryLabel,
    required this.secondaryAction,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final DuplicateItemAction primaryAction;
  final String secondaryLabel;
  final DuplicateItemAction secondaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerHighest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
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
              onPressed: () => Navigator.of(context).pop(primaryAction),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(primaryLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(secondaryAction),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: colorScheme.onSurface,
              ),
              child: Text(secondaryLabel),
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
