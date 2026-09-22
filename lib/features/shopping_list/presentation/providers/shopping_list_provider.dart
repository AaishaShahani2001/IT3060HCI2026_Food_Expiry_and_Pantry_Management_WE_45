import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>(
  (ref) => ShoppingListRepository(),
);

// Feature-scoped: no changes to the team's authentication implementation.
final shoppingAuthUidProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct();
});

enum ShoppingDuplicateAction { increaseQuantity, moveToBuy, addAnyway }

enum LowStockShoppingResult { unchanged, added, reactivated }

class ShoppingDuplicateException implements Exception {
  const ShoppingDuplicateException(this.existing);
  final ShoppingItem existing;
}

class ShoppingQuantityLimitException implements Exception {
  const ShoppingQuantityLimitException();
}

class ShoppingListNotifier extends AsyncNotifier<List<ShoppingItem>> {
  String? _uid;
  int _generation = 0;
  Completer<void> _idle = Completer<void>()..complete();
  bool get _mutationInProgress => !_idle.isCompleted;
  set _mutationInProgress(bool busy) {
    if (busy) {
      _idle = Completer<void>();
    } else if (!_idle.isCompleted) {
      _idle.complete();
    }
  }

  ShoppingListRepository get _repository =>
      ref.read(shoppingListRepositoryProvider);

  @override
  Future<List<ShoppingItem>> build() async {
    final generation = ++_generation;
    _uid = null;
    _mutationInProgress = false;
    ref.onDispose(() => _mutationInProgress = false);
    final repository = ref.watch(shoppingListRepositoryProvider);
    final uid = await ref.watch(shoppingAuthUidProvider.future);
    if (!ref.mounted || generation != _generation) return [];
    _uid = uid;
    if (uid == null) return [];
    final items = await repository.getShoppingItems(uid);
    return _isCurrent(generation, uid) ? items : [];
  }

  bool _isCurrent(int generation, String uid) =>
      ref.mounted &&
      generation == _generation &&
      _uid == uid &&
      _repository.isCurrentUser(uid);

  String _requireUser() {
    final uid = _uid;
    if (uid == null || !_repository.isCurrentUser(uid)) {
      throw StateError('Please sign in again to use your shopping list.');
    }
    if (state.isLoading || state.asData == null || _mutationInProgress) {
      throw StateError('Please wait for the current shopping operation.');
    }
    return uid;
  }

  Future<void> reload() async {
    if (_mutationInProgress) return;
    if (state.asData == null) {
      ref.invalidateSelf();
      await future;
      return;
    }
    final uid = _requireUser();
    final generation = _generation;
    _mutationInProgress = true;
    try {
      final items = await _repository.getShoppingItems(uid);
      if (_isCurrent(generation, uid)) state = AsyncData(items);
      // Retain valid data on a failed refresh; the caller supplies feedback.
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  String _normalizedName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  ShoppingItem? findDuplicate(String name, {String? excludeId}) {
    _requireUser();
    final matches = state.requireValue
        .where(
          (item) =>
              item.id != excludeId &&
              _normalizedName(item.name) == _normalizedName(name),
        )
        .toList();
    // Intentional duplicates may already exist. Prefer To Buy, then a stable ID.
    matches.sort((a, b) {
      if (a.isPurchased != b.isPurchased) return a.isPurchased ? 1 : -1;
      return (a.id ?? '').compareTo(b.id ?? '');
    });
    return matches.isEmpty ? null : matches.first;
  }

  bool _sameItem(ShoppingItem a, ShoppingItem? b) =>
      b != null &&
      a.id == b.id &&
      a.name == b.name &&
      a.quantity == b.quantity &&
      a.isPurchased == b.isPurchased;

  Future<ShoppingItem> addItem(
    ShoppingItem item, {
    ShoppingDuplicateAction? duplicateAction,
    ShoppingItem? confirmedDuplicate,
  }) async {
    final uid = _requireUser();
    if (item.id != null ||
        item.name.trim().isEmpty ||
        item.quantity < 1 ||
        item.quantity > 100) {
      throw ArgumentError(
        'Enter a new item name and a quantity from 1 to 100.',
      );
    }
    final duplicate = findDuplicate(item.name);
    if (duplicate != null) {
      if (duplicateAction == null ||
          !_sameItem(duplicate, confirmedDuplicate) ||
          (duplicateAction == ShoppingDuplicateAction.moveToBuy &&
              !duplicate.isPurchased) ||
          (duplicateAction == ShoppingDuplicateAction.increaseQuantity &&
              duplicate.isPurchased)) {
        throw ShoppingDuplicateException(duplicate);
      }
      if (duplicateAction != ShoppingDuplicateAction.addAnyway) {
        final quantity = duplicate.isPurchased
            ? item.quantity
            : duplicate.quantity + item.quantity;
        if (quantity > 100) throw const ShoppingQuantityLimitException();
        final updated = duplicate.copyWith(
          quantity: quantity,
          isPurchased: false,
        );
        await updateItem(duplicate.id!, updated);
        return updated;
      }
    } else if (duplicateAction != null &&
        duplicateAction != ShoppingDuplicateAction.addAnyway) {
      throw StateError('The duplicate changed. Please try again.');
    }
    final generation = _generation;
    _mutationInProgress = true;
    try {
      final createdItem = await _repository.addShoppingItem(uid, item);
      if (_isCurrent(generation, uid)) {
        state = AsyncData([...state.requireValue, createdItem]);
      }
      return createdItem;
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  Future<ShoppingItem> saveEditedItem(
    ShoppingItem item, {
    ShoppingItem? confirmedDuplicate,
  }) async {
    _requireUser();
    final originals = state.requireValue.where((saved) => saved.id == item.id);
    if (item.id == null || originals.isEmpty) {
      throw StateError('The shopping item changed. Please refresh.');
    }
    final duplicate = findDuplicate(item.name, excludeId: item.id);
    if (duplicate != null && !_sameItem(duplicate, confirmedDuplicate)) {
      throw ShoppingDuplicateException(duplicate);
    }
    // Editing name/quantity never changes the current Bought status.
    final updated = originals.single.copyWith(
      name: item.name,
      quantity: item.quantity,
    );
    await updateItem(item.id!, updated);
    return updated;
  }

  Future<void> deleteItem(String itemId) => deleteItems([itemId]);

  Future<void> deleteItems(List<String> itemIds) async {
    final uid = _requireUser();
    final generation = _generation;
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;
    final visibleIds = state.requireValue.map((item) => item.id).toSet();
    if (!ids.every(visibleIds.contains)) {
      throw StateError('The shopping list changed. Reload before deleting.');
    }
    _mutationInProgress = true;
    try {
      await _repository.deleteShoppingItems(uid, ids.toList());
      if (_isCurrent(generation, uid)) {
        state = AsyncData(
          state.requireValue.where((item) => !ids.contains(item.id)).toList(),
        );
      }
      // On any failure, leave the displayed list intact and let the UI report it.
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  Future<void> updateItem(String itemId, ShoppingItem item) async {
    final uid = _requireUser();
    final generation = _generation;
    final previous = state.requireValue;
    if (item.id != itemId || !previous.any((saved) => saved.id == itemId)) {
      throw StateError('The shopping item changed. Refresh before updating.');
    }
    if (item.name.trim().isEmpty || item.quantity < 1 || item.quantity > 100) {
      throw ArgumentError('Enter an item name and a quantity from 1 to 100.');
    }
    final updated = item.copyWith(name: item.name.trim());
    final existing = previous.firstWhere((saved) => saved.id == itemId);
    if (existing.name == updated.name &&
        existing.quantity == updated.quantity &&
        existing.isPurchased == updated.isPurchased) {
      return;
    }

    _mutationInProgress = true;
    // Counts and rows respond immediately; rejected writes restore saved state.
    state = AsyncData([
      for (final saved in previous)
        if (saved.id == itemId) updated else saved,
    ]);
    try {
      await _repository.updateShoppingItem(uid, updated);
    } catch (_) {
      if (_isCurrent(generation, uid)) state = AsyncData(previous);
      rethrow;
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  Future<void> togglePurchased(String itemId, bool isPurchased) async {
    _requireUser();
    final matches = state.requireValue.where((item) => item.id == itemId);
    if (matches.isEmpty) {
      throw StateError('The shopping item changed. Refresh before updating.');
    }
    await updateItem(itemId, matches.single.copyWith(isPurchased: isPurchased));
  }

  /// Background sync shares the manual-operation lock, but never opens a
  /// duplicate dialog or changes a manual item. The owner and stock episode are
  /// rechecked after each wait, before issuing a write.
  Future<LowStockShoppingResult> ensureLowStockItem({
    required String expectedUid,
    required String pantryItemId,
    required String name,
    required bool reactivateBought,
    required bool Function() stillEligible,
  }) async {
    await future;
    while (ref.mounted && _mutationInProgress) {
      await _idle.future;
    }
    if (!ref.mounted || _uid != expectedUid || !stillEligible()) {
      return LowStockShoppingResult.unchanged;
    }
    final uid = _requireUser();
    if (pantryItemId.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('A saved Pantry item is required.');
    }
    final generation = _generation;
    _mutationInProgress = true;
    try {
      // Refresh before matching: another screen/device may have added an item
      // since this notifier loaded. This is not a cross-device transaction.
      final items = await _repository.getShoppingItems(uid);
      if (!_isCurrent(generation, uid) || !stillEligible()) {
        return LowStockShoppingResult.unchanged;
      }
      state = AsyncData(items);
      final matches = items
          .where(
            (item) =>
                item.sourcePantryItemId == pantryItemId ||
                _normalizedName(item.name) == _normalizedName(name),
          )
          .toList();
      if (matches.any((item) => !item.isPurchased)) {
        return LowStockShoppingResult.unchanged;
      }
      final linked =
          matches
              .where(
                (item) =>
                    item.source == 'low_stock' &&
                    item.sourcePantryItemId == pantryItemId,
              )
              .toList()
            ..sort((a, b) => a.id!.compareTo(b.id!));
      if (linked.isNotEmpty && reactivateBought) {
        final updated = linked.first.copyWith(isPurchased: false);
        await _repository.updateShoppingItem(uid, updated);
        if (_isCurrent(generation, uid)) {
          state = AsyncData([
            for (final item in items)
              if (item.id == updated.id) updated else item,
          ]);
        }
        return LowStockShoppingResult.reactivated;
      }
      // Startup Bought matches, including manual Bought items, are respected.
      if (matches.isNotEmpty) return LowStockShoppingResult.unchanged;
      final created = await _repository.addShoppingItem(
        uid,
        ShoppingItem(
          name: name.trim(),
          quantity: 1,
          source: 'low_stock',
          sourcePantryItemId: pantryItemId,
        ),
      );
      if (_isCurrent(generation, uid)) {
        state = AsyncData([...items, created]);
      }
      return LowStockShoppingResult.added;
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }
}

final shoppingListProvider =
    AsyncNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );
