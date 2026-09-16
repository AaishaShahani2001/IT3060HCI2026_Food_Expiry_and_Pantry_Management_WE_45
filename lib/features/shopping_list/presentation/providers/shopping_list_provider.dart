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

class ShoppingListNotifier extends AsyncNotifier<List<ShoppingItem>> {
  String? _uid;
  int _generation = 0;
  bool _mutationInProgress = false;

  ShoppingListRepository get _repository =>
      ref.read(shoppingListRepositoryProvider);

  @override
  Future<List<ShoppingItem>> build() async {
    final generation = ++_generation;
    _uid = null;
    _mutationInProgress = false;
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
    ref.invalidateSelf();
    await future;
  }

  Future<void> addItem(ShoppingItem item) async {
    final uid = _requireUser();
    final generation = _generation;
    _mutationInProgress = true;
    try {
      final createdItem = await _repository.addShoppingItem(uid, item);
      if (_isCurrent(generation, uid)) {
        state = AsyncData([...state.requireValue, createdItem]);
      }
    } finally {
      if (ref.mounted && generation == _generation) _mutationInProgress = false;
    }
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

  // Editing and purchasing remain local-only in this phase.
  void updateItem(String itemId, ShoppingItem item) {
    _requireUser();
    state = AsyncData([
      for (final existing in state.requireValue)
        if (existing.id == itemId) item.copyWith(id: itemId) else existing,
    ]);
  }

  void togglePurchased(String itemId, bool isPurchased) {
    _requireUser();
    state = AsyncData([
      for (final item in state.requireValue)
        if (item.id == itemId)
          item.copyWith(isPurchased: isPurchased)
        else
          item,
    ]);
  }
}

final shoppingListProvider =
    AsyncNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );
