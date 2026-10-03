import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../shopping_list/models/shopping_item.dart';
import '../../../shopping_list/models/shopping_item_draft.dart';
import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/models/removed_pantry_item.dart';
import '../providers/pantry_providers.dart';
import '../screens/pantry_item_form_screen.dart';
import '../widgets/pantry_item_form.dart';
import '../widgets/pantry_item_dialogs.dart';
import 'pantry_snackbar.dart';

/// Document ids whose Used Up undo is currently writing.
final Set<String> _usedUpRestoresInFlight = <String>{};

/// Snapshots that already restored successfully. A failed restore clears its
/// claim so Retry can try again. A new Used Up creates a new snapshot.
final Expando<bool> _usedUpUndoClaimed = Expando<bool>();

Future<void> openPantryAddItem(
  BuildContext context, {
  PantryItemFormPrefill? prefill,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => PantryItemFormScreen(prefill: prefill)),
  );
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

  // Capture these before the item card leaves the tree. The screen messenger
  // and router stay valid after that card is removed.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.maybeOf(context);
  final notifier = ref.read(pantryItemsProvider.notifier);
  if (messenger == null) return;

  try {
    final removed = await notifier.markAsUsedUp(
      item,
      originalIndex: originalIndex,
    );
    if (removed == null || !messenger.mounted) return;

    _showUsedUpSnackBar(
      messenger: messenger,
      notifier: notifier,
      removed: removed,
      router: router,
    );
    onRemoved?.call();
  } catch (error) {
    debugPrint('Pantry Used Up UI failed: $error');
    if (!messenger.mounted) return;
    PantrySnackBar.errorOn(
      messenger,
      error is PantryFirestoreException
          ? error.message
          : 'Unable to mark ${item.name} as used up. Please try again.',
    );
  }
}

void _showUsedUpSnackBar({
  required ScaffoldMessengerState messenger,
  required PantryItemsNotifier notifier,
  required RemovedPantryItem removed,
  required GoRouter? router,
}) {
  PantrySnackBar.showUsedUp(
    messenger,
    itemName: removed.name,
    onUndo: () {
      unawaited(_restoreUsedUp(messenger, notifier, removed));
    },
    onAddToList: () {
      unawaited(_openShoppingListForUsedUp(router, messenger, removed));
    },
  );
}

Future<void> _openShoppingListForUsedUp(
  GoRouter? router,
  ScaffoldMessengerState messenger,
  RemovedPantryItem removed,
) async {
  final navigation = router;
  if (navigation == null) {
    debugPrint('Shopping List route is unavailable.');
    return;
  }

  final draft = ShoppingItemDraft.fromPantryItem(removed.item);
  // Query values avoid casting route extra as ShoppingItem. The add route
  // turns these parameters back into a ShoppingItemDraft.
  final saved = await navigation.push<ShoppingItem>(
    Uri(
      path: AppRoutes.addShoppingItem,
      queryParameters: {
        if (draft.name != null && draft.name!.isNotEmpty) 'name': draft.name!,
        if (draft.category != null && draft.category!.isNotEmpty)
          'category': draft.category!,
        if (draft.unit != null) 'unit': draft.unit!.name,
      },
    ).toString(),
  );
  if (saved == null || !messenger.mounted) return;
  PantrySnackBar.showOn(
    messenger,
    message: '${saved.name} added to your Shopping List.',
    duration: PantrySnackBar.standard,
  );
}

Future<void> _restoreUsedUp(
  ScaffoldMessengerState messenger,
  PantryItemsNotifier notifier,
  RemovedPantryItem removed,
) async {
  final restoreKey = removed.documentId;
  if (_usedUpUndoClaimed[removed] == true) return;
  if (!_usedUpRestoresInFlight.add(restoreKey)) return;
  _usedUpUndoClaimed[removed] = true;

  try {
    await notifier.restoreUsedUpItem(removed);
    if (!messenger.mounted) return;
    PantrySnackBar.showOn(
      messenger,
      message: '${removed.name} restored.',
      duration: PantrySnackBar.confirmation,
    );
  } catch (error) {
    _usedUpUndoClaimed[removed] = false;
    debugPrint('Pantry Used Up undo UI failed: $error');
    if (!messenger.mounted) return;
    PantrySnackBar.showOn(
      messenger,
      isError: true,
      message: 'Unable to restore ${removed.name}. Please try again.',
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () {
          unawaited(_restoreUsedUp(messenger, notifier, removed));
        },
      ),
    );
  } finally {
    _usedUpRestoresInFlight.remove(restoreKey);
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
          duration: PantrySnackBar.quantityUndo,
          persist: false,
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
      duration: PantrySnackBar.confirmation,
    );
  } catch (error) {
    debugPrint('Pantry quantity undo UI failed: $error');
    PantrySnackBar.errorOn(
      messenger,
      'Unable to update ${writeResult.itemName} quantity. Please try again.',
    );
  }
}
