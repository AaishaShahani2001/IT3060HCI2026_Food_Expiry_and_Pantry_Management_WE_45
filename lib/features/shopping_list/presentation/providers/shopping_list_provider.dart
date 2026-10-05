import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/shared_pantry/data/shared_pantry_service.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/low_stock_eligibility.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_item_metadata.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_scope.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>(
  (ref) => ShoppingListRepository(),
);

typedef ShoppingPantryDisplayNameLoader =
    Future<String?> Function(String pantryId);

/// Reads display-only household metadata from the canonical Pantry document.
/// Personal versus shared scope remains owned by [shoppingScopeProvider].
final shoppingPantryDisplayNameLoaderProvider =
    Provider<ShoppingPantryDisplayNameLoader>((ref) {
      return (pantryId) async {
        final pantry = await SharedPantryService.instance.getPantry(pantryId);
        final name = pantry.data()?['name']?.toString().trim();
        return name == null || name.isEmpty ? null : name;
      };
    });

/// Family-keying prevents a previous household name from being reused while a
/// different Pantry name is loading.
final shoppingPantryDisplayNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, pantryId) {
      return ref.watch(shoppingPantryDisplayNameLoaderProvider)(pantryId);
    });

// Feature-scoped: no changes to the team's authentication implementation.
final shoppingAuthUidProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct();
});

/// Resolves Personal versus Family/Shared Shopping from the existing active
/// Pantry context. Auth or profile changes rebuild this provider, which cancels
/// the previous scope listener before the Shopping collection is switched.
final shoppingScopeProvider = StreamProvider<ShoppingScope?>((ref) {
  final repository = ref.watch(shoppingListRepositoryProvider);
  return ref
      .watch(shoppingAuthUidProvider)
      .when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        data: (uid) => uid == null
            ? Stream<ShoppingScope?>.value(null)
            : repository.watchScope(uid).map<ShoppingScope?>((scope) => scope),
        error: (error, stackTrace) =>
            Stream<ShoppingScope?>.error(error, stackTrace),
        loading: () => const Stream<ShoppingScope?>.empty(),
      );
});

enum ShoppingDuplicateAction { increaseQuantity, moveToBuy, addAnyway }

enum LowStockShoppingResult { unchanged, added, reactivated }

class ExpiredLowStockSuggestionException implements Exception {
  const ExpiredLowStockSuggestionException();
}

class ShoppingDuplicateException implements Exception {
  const ShoppingDuplicateException(this.existing);
  final ShoppingItem existing;
}

class ShoppingQuantityLimitException implements Exception {
  const ShoppingQuantityLimitException();
}

class ShoppingListNotifier extends AsyncNotifier<List<ShoppingItem>> {
  ShoppingScope? _scope;
  int _generation = 0;
  Completer<void> _idle = Completer<void>()..complete();
  bool get _mutationInProgress => !_idle.isCompleted;
  bool get mutationInProgress => _mutationInProgress;
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
    _scope = null;
    _mutationInProgress = false;
    ref.onDispose(() => _mutationInProgress = false);
    final repository = ref.watch(shoppingListRepositoryProvider);
    final scope = await ref.watch(shoppingScopeProvider.future);
    if (!ref.mounted || generation != _generation) return [];
    _scope = scope;
    if (scope == null) return [];

    final initial = Completer<List<ShoppingItem>>();
    late final StreamSubscription<List<ShoppingItem>> subscription;
    subscription = repository
        .watchShoppingItems(scope)
        .listen(
          (items) {
            if (!_isCurrent(generation, scope)) return;
            if (!initial.isCompleted) {
              initial.complete(items);
            } else {
              state = AsyncData(items);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!_isCurrent(generation, scope)) return;
            if (!initial.isCompleted) {
              initial.completeError(error, stackTrace);
            } else {
              state = AsyncError(error, stackTrace);
            }
          },
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return initial.future;
  }

  bool _isCurrent(int generation, ShoppingScope scope) =>
      ref.mounted &&
      generation == _generation &&
      _scope == scope &&
      _repository.isCurrentScope(scope);

  ShoppingScope _requireScope() {
    final scope = _scope;
    if (scope == null || !_repository.isCurrentScope(scope)) {
      throw StateError('Please sign in again to use your shopping list.');
    }
    if (state.isLoading || state.asData == null || _mutationInProgress) {
      throw StateError('Please wait for the current shopping operation.');
    }
    return scope;
  }

  Future<void> reload() async {
    if (_mutationInProgress) return;
    if (state.asData == null) {
      ref.invalidateSelf();
      await future;
      return;
    }
    final scope = _requireScope();
    final generation = _generation;
    _mutationInProgress = true;
    try {
      final items = await _repository.getShoppingItemsForScope(scope);
      if (_isCurrent(generation, scope)) state = AsyncData(items);
      // Retain valid data on a failed refresh; the caller supplies feedback.
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  String _normalizedName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  List<ShoppingItem> _upsert(
    Iterable<ShoppingItem> items,
    ShoppingItem replacement,
  ) => [...items.where((item) => item.id != replacement.id), replacement];

  ShoppingItem? findDuplicate(String name, {String? excludeId}) {
    _requireScope();
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
      a.isPurchased == b.isPurchased &&
      a.unit == b.unit &&
      a.category == b.category;

  Future<ShoppingItem> addItem(
    ShoppingItem item, {
    ShoppingDuplicateAction? duplicateAction,
    ShoppingItem? confirmedDuplicate,
  }) async {
    final scope = _requireScope();
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
              (duplicate.isPurchased || duplicate.unit != item.unit))) {
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
          unit: duplicate.isPurchased ? item.unit : duplicate.unit,
          category: duplicate.isPurchased ? item.category : duplicate.category,
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
      final createdItem = await _repository.addShoppingItemForScope(
        scope,
        item,
      );
      if (_isCurrent(generation, scope)) {
        state = AsyncData(_upsert(state.requireValue, createdItem));
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
    _requireScope();
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
      unit: item.unit,
      category: item.category,
    );
    await updateItem(item.id!, updated);
    return updated;
  }

  Future<void> deleteItem(String itemId) => deleteItems([itemId]);

  Future<void> deleteItems(List<String> itemIds) async {
    final scope = _requireScope();
    final generation = _generation;
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;
    final previous = state.requireValue;
    final visibleIds = previous.map((item) => item.id).toSet();
    if (!ids.every(visibleIds.contains)) {
      throw StateError('The shopping list changed. Reload before deleting.');
    }
    _mutationInProgress = true;
    try {
      await _repository.deleteShoppingItemsForScope(scope, ids.toList());
      if (_isCurrent(generation, scope)) {
        state = AsyncData(
          state.requireValue.where((item) => !ids.contains(item.id)).toList(),
        );
      }
    } catch (_) {
      if (_isCurrent(generation, scope)) state = AsyncData(previous);
      rethrow;
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  Future<void> updateItem(String itemId, ShoppingItem item) async {
    final scope = _requireScope();
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
        existing.isPurchased == updated.isPurchased &&
        existing.unit == updated.unit &&
        existing.category == updated.category) {
      return;
    }

    _mutationInProgress = true;
    // Counts and rows respond immediately; rejected writes restore saved state.
    state = AsyncData([
      for (final saved in previous)
        if (saved.id == itemId) updated else saved,
    ]);
    try {
      await _repository.updateShoppingItemForScope(scope, updated);
      if (_isCurrent(generation, scope)) {
        state = AsyncData([
          for (final saved in state.requireValue)
            if (saved.id == itemId) updated else saved,
        ]);
      }
    } catch (_) {
      if (_isCurrent(generation, scope)) state = AsyncData(previous);
      rethrow;
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  Future<void> togglePurchased(String itemId, bool isPurchased) async {
    _requireScope();
    final matches = state.requireValue.where((item) => item.id == itemId);
    if (matches.isEmpty) {
      throw StateError('The shopping item changed. Refresh before updating.');
    }
    await updateItem(itemId, matches.single.copyWith(isPurchased: isPurchased));
  }

  Future<ShoppingItem?> addLowStockSuggestion(
    PantryItem pantryItem, {
    double? threshold,
  }) async {
    final scope = _requireScope();
    final effectiveThreshold = threshold ?? pantryItem.minQuantity;
    if (!hasEligibleShoppingLowStockExpiry(pantryItem)) {
      throw const ExpiredLowStockSuggestionException();
    }
    if (!pantryItem.isConnectedToFirestore ||
        pantryItem.name.trim().isEmpty ||
        !pantryItem.quantity.isFinite ||
        pantryItem.quantity > effectiveThreshold) {
      throw ArgumentError('This Pantry item is not a low-stock suggestion.');
    }
    if (findDuplicate(pantryItem.name) != null) return null;
    final generation = _generation;
    _mutationInProgress = true;
    try {
      final result = await _repository.createLowStockIfAbsent(
        scope: scope,
        pantryItemId: pantryItem.firestoreId!,
        item: ShoppingItem(
          name: pantryItem.name.trim(),
          quantity: 1,
          unit: pantryItem.unit,
          category: shoppingCategoryForPantryItem(pantryItem),
          source: 'low_stock',
          sourcePantryItemId: pantryItem.firestoreId,
        ),
      );
      if (_isCurrent(generation, scope)) {
        state = AsyncData(_upsert(state.requireValue, result.item));
      }
      return result.created ? result.item : null;
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }

  Future<int> addLowStockSuggestions(
    Iterable<PantryItem> pantryItems, {
    Map<PantryCategory, int>? categoryThresholds,
  }) async {
    _requireScope();
    var addedCount = 0;
    for (final pantryItem in pantryItems) {
      final added = await addLowStockSuggestion(
        pantryItem,
        threshold: categoryThresholds == null
            ? null
            : (categoryThresholds[pantryItem.category] ?? 1) *
                  pantryItem.minQuantity,
      );
      if (added != null) addedCount++;
    }
    return addedCount;
  }

  /// Background sync shares the manual-operation lock, but never opens a
  /// duplicate dialog or changes a manual item. The owner and stock episode are
  /// rechecked after each wait, before issuing a write.
  Future<LowStockShoppingResult> ensureLowStockItem({
    required ShoppingScope expectedScope,
    required String pantryItemId,
    required String name,
    required bool reactivateBought,
    required bool Function() stillEligible,
  }) async {
    await future;
    while (ref.mounted && _mutationInProgress) {
      await _idle.future;
    }
    if (!ref.mounted || _scope != expectedScope || !stillEligible()) {
      return LowStockShoppingResult.unchanged;
    }
    final scope = _requireScope();
    if (pantryItemId.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('A saved Pantry item is required.');
    }
    final generation = _generation;
    _mutationInProgress = true;
    try {
      // Refresh before matching: another screen/device may have added an item
      // since this notifier loaded. The linked create below is protected by a
      // Firestore transaction.
      final items = await _repository.getShoppingItemsForScope(scope);
      if (!_isCurrent(generation, scope) || !stillEligible()) {
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
        await _repository.updateShoppingItemForScope(scope, updated);
        if (_isCurrent(generation, scope)) {
          state = AsyncData([
            for (final item in items)
              if (item.id == updated.id) updated else item,
          ]);
        }
        return LowStockShoppingResult.reactivated;
      }
      // Startup Bought matches, including manual Bought items, are respected.
      if (matches.isNotEmpty) return LowStockShoppingResult.unchanged;
      final result = await _repository.createLowStockIfAbsent(
        scope: scope,
        pantryItemId: pantryItemId,
        item: ShoppingItem(
          name: name.trim(),
          quantity: 1,
          source: 'low_stock',
          sourcePantryItemId: pantryItemId,
        ),
      );
      if (_isCurrent(generation, scope)) {
        state = AsyncData(_upsert(items, result.item));
      }
      return result.created
          ? LowStockShoppingResult.added
          : LowStockShoppingResult.unchanged;
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
  }
}

final shoppingListProvider =
    AsyncNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );
