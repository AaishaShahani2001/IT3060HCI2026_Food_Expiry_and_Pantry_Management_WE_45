import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/models/removed_pantry_item.dart';
import '../providers/pantry_providers.dart';
import '../screens/pantry_item_form_screen.dart';
import '../widgets/pantry_item_dialogs.dart';
import 'pantry_snackbar.dart';

Future<void> openPantryAddItem(BuildContext context) {
  return Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => const PantryItemFormScreen()));
}

Future<void> openPantryItemEditor(BuildContext context, PantryItem item) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => PantryItemFormScreen(item: item)),
  );
}

Future<void> handlePantryUsedUp({
  required BuildContext context,
  required WidgetRef ref,
  required PantryItem item,
  required int originalIndex,
  VoidCallback? onRemoved,
}) async {
  if (ref.read(pantryBusyItemIdsProvider).contains(item.id)) return;

  try {
    final removed = await ref
        .read(pantryItemsProvider.notifier)
        .markAsUsedUp(item, originalIndex: originalIndex);
    if (removed == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(pantryItemsProvider.notifier);
    _showUsedUpSnackBar(messenger, notifier, removed);
    onRemoved?.call();
  } catch (error) {
    debugPrint('Pantry Used Up UI failed: $error');
    if (!context.mounted) return;
    PantrySnackBar.error(
      context,
      error is PantryFirestoreException
          ? error.message
          : 'Unable to mark ${item.name} as used up. Please try again.',
    );
  }
}

void _showUsedUpSnackBar(
  ScaffoldMessengerState messenger,
  PantryItemsNotifier notifier,
  RemovedPantryItem removed,
) {
  PantrySnackBar.showOn(
    messenger,
    message: '${removed.name} marked as used up.',
    action: SnackBarAction(
      label: 'UNDO',
      onPressed: () {
        _restoreUsedUp(messenger, notifier, removed);
      },
    ),
  );
}

Future<void> _restoreUsedUp(
  ScaffoldMessengerState messenger,
  PantryItemsNotifier notifier,
  RemovedPantryItem removed,
) async {
  try {
    await notifier.restoreUsedUpItem(removed);
    PantrySnackBar.showOn(messenger, message: '${removed.name} restored.');
  } catch (error) {
    debugPrint('Pantry Used Up undo UI failed: $error');
    PantrySnackBar.showOn(
      messenger,
      isError: true,
      message: 'Unable to restore ${removed.name}. Please try again.',
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () {
          _restoreUsedUp(messenger, notifier, removed);
        },
      ),
    );
  }
}

Future<void> handlePantryPermanentDelete({
  required BuildContext context,
  required WidgetRef ref,
  required PantryItem item,
  VoidCallback? onRemoved,
}) async {
  if (ref.read(pantryBusyItemIdsProvider).contains(item.id)) return;

  final confirmed = await confirmDeletePantryItem(context, itemName: item.name);
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(pantryItemsProvider.notifier).permanentlyDelete(item);
    if (!context.mounted) return;
    PantrySnackBar.show(
      context,
      message: '${item.name} deleted from your pantry.',
    );
    onRemoved?.call();
  } catch (error) {
    debugPrint('Pantry delete UI failed: $error');
    if (!context.mounted) return;
    PantrySnackBar.error(
      context,
      error is PantryFirestoreException
          ? error.message
          : 'Unable to delete ${item.name}. Please try again.',
    );
  }
}

Future<void> handlePantryQuantityDelta({
  required BuildContext context,
  required WidgetRef ref,
  required PantryItem item,
  required double delta,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(pantryItemsProvider.notifier);

  final result = notifier.changeQuantityOptimistically(
    item: item,
    delta: delta,
    onFlushed: (writeResult) {
      if (writeResult.success) {
        PantrySnackBar.showOn(
          messenger,
          message:
              '${writeResult.itemName} quantity updated to ${writeResult.quantityLabel}.',
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              _undoQuantity(messenger, notifier, writeResult);
            },
          ),
        );
      } else {
        PantrySnackBar.errorOn(
          messenger,
          'Unable to update ${writeResult.itemName} quantity. Please try again.',
        );
      }
    },
  );

  if (result == PantryQuantityChangeResult.wouldGoNegative) {
    final markUsedUp = await showNoQuantityRemainingDialog(
      context,
      itemName: item.name,
    );
    if (markUsedUp != true || !context.mounted) return;

    final items = ref.read(pantryItemsProvider).asData?.value ?? const [];
    final index = items.indexWhere((entry) => entry.id == item.id);
    await handlePantryUsedUp(
      context: context,
      ref: ref,
      item: item,
      originalIndex: index < 0 ? 0 : index,
    );
  }
}

Future<void> _undoQuantity(
  ScaffoldMessengerState messenger,
  PantryItemsNotifier notifier,
  PantryQuantityWriteResult writeResult,
) async {
  try {
    await notifier.undoQuantityChange(writeResult.itemId);
    PantrySnackBar.showOn(
      messenger,
      message: '${writeResult.itemName} quantity restored.',
    );
  } catch (error) {
    debugPrint('Pantry quantity undo UI failed: $error');
    PantrySnackBar.errorOn(
      messenger,
      'Unable to update ${writeResult.itemName} quantity. Please try again.',
    );
  }
}
