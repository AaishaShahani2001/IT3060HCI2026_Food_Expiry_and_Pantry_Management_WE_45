import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_expiry_and_pantry_management/core/services/auth_service.dart';
import 'package:food_expiry_and_pantry_management/features/shared_pantry/data/shared_pantry_service.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

import 'shopping_scope.dart';

typedef ShoppingScopeStream = Stream<ShoppingScope> Function(String uid);

class LowStockShoppingWriteResult {
  const LowStockShoppingWriteResult({
    required this.item,
    required this.created,
  });

  final ShoppingItem item;
  final bool created;
}

/// A later batch can fail after earlier batches have already committed.
class ShoppingListDeleteException implements Exception {
  final Object cause;
  final List<String> deletedItemIds;

  ShoppingListDeleteException(this.cause, List<String> deletedItemIds)
    : deletedItemIds = List.unmodifiable(deletedItemIds);

  @override
  String toString() =>
      'Deleted ${deletedItemIds.length} items before deletion failed: $cause';
}

class ShoppingListRepository {
  ShoppingListRepository({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    ShoppingScopeStream? scopeStream,
    Future<ActivePantryContext> Function()? activePantryContext,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ?? (() => AuthService.instance.currentUser?.uid),
       _scopeStream = scopeStream,
       _injectedAuthUsesPersonalScope =
           scopeStream == null && currentUid != null,
       _activePantryContext = activePantryContext;

  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;
  final ShoppingScopeStream? _scopeStream;
  final bool _injectedAuthUsesPersonalScope;
  final Future<ActivePantryContext> Function()? _activePantryContext;
  ShoppingScope? _currentScope;
  static const _deleteBatchSize = 400;

  bool isCurrentUser(String uid) =>
      uid.isNotEmpty && !uid.contains('/') && _currentUid() == uid;

  bool isCurrentScope(ShoppingScope scope) =>
      isCurrentUser(scope.actorUid) &&
      _validScope(scope) &&
      (_currentScope == null || _currentScope == scope);

  bool _validScope(ShoppingScope scope) {
    try {
      if (scope.isShared) {
        ShoppingScope.shared(
          actorUid: scope.actorUid,
          pantryId: scope.pantryId ?? '',
        );
      } else {
        ShoppingScope.personal(scope.actorUid);
      }
      return true;
    } on ArgumentError {
      return false;
    }
  }

  void _checkScope(ShoppingScope scope) {
    if (!isCurrentScope(scope)) {
      throw StateError('Your Shopping scope changed. Please try again.');
    }
  }

  Stream<ShoppingScope> watchScope(String uid) {
    if (!isCurrentUser(uid)) return const Stream<ShoppingScope>.empty();
    final injected = _scopeStream;
    if (injected != null) {
      return injected(uid)
          .where((scope) => isCurrentUser(scope.actorUid) && _validScope(scope))
          .map((scope) {
            _currentScope = scope;
            return scope;
          })
          .distinct();
    }
    // SDK-boundary tests inject currentUid and remain personal unless they
    // explicitly supply a scope stream. Production follows the existing
    // SharedPantryService context and refreshes it whenever the user profile
    // changes.
    if (_injectedAuthUsesPersonalScope) {
      final scope = ShoppingScope.personal(uid);
      _currentScope = scope;
      return Stream.value(scope);
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((_) async {
          if (!isCurrentUser(uid)) return null;
          final context =
              await (_activePantryContext ??
                  SharedPantryService.instance.getActivePantryContext)();
          if (!isCurrentUser(uid)) return null;
          late final ShoppingScope scope;
          if (context.pantryType == 'personal') {
            scope = ShoppingScope.personal(uid);
          } else if ((context.pantryType == 'family' ||
                  context.pantryType == 'shared') &&
              context.pantryId != null &&
              context.pantryId!.isNotEmpty) {
            scope = ShoppingScope.shared(
              actorUid: uid,
              pantryId: context.pantryId!,
            );
          } else {
            throw StateError('No active Shopping scope is available.');
          }
          _currentScope = scope;
          return scope;
        })
        .where((scope) => scope != null)
        .cast<ShoppingScope>()
        .distinct();
  }

  CollectionReference<Map<String, dynamic>> _itemsForScope(
    ShoppingScope scope,
  ) {
    _checkScope(scope);
    return _firestore.collection(scope.collectionPath);
  }

  List<ShoppingItem> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .map((document) => ShoppingItem.fromMap(document.id, document.data()))
          .toList();

  Stream<List<ShoppingItem>> watchShoppingItems(ShoppingScope scope) {
    // Legacy SDK-boundary tests that inject only currentUid provide a minimal
    // Firestore fake with get(), but no snapshot implementation. Production
    // and scope-aware tests always use the realtime branch below.
    if (_injectedAuthUsesPersonalScope) {
      return Stream.fromFuture(getShoppingItemsForScope(scope));
    }
    final collection = _itemsForScope(scope);
    return collection.snapshots().map((snapshot) {
      _checkScope(scope);
      return _decode(snapshot);
    });
  }

  Future<List<ShoppingItem>> getShoppingItemsForScope(
    ShoppingScope scope,
  ) async {
    final snapshot = await _itemsForScope(scope).get();
    _checkScope(scope);
    return _decode(snapshot);
  }

  /// Compatibility wrapper for callers that intentionally require a personal
  /// list. Shared-aware production code uses [getShoppingItemsForScope].
  Future<List<ShoppingItem>> getShoppingItems(String uid) async {
    return getShoppingItemsForScope(ShoppingScope.personal(uid));
  }

  Future<ShoppingItem> addShoppingItemForScope(
    ShoppingScope scope,
    ShoppingItem item,
  ) async {
    if (item.id != null) {
      throw ArgumentError('Only a new item can be saved.');
    }
    if (item.name.trim().isEmpty || item.quantity < 1 || item.quantity > 100) {
      throw ArgumentError('Enter an item name and a quantity from 1 to 100.');
    }
    final savedItem = item.copyWith(name: item.name.trim());
    final document = await _itemsForScope(scope).add(savedItem.toMap());
    return savedItem.copyWith(id: document.id);
  }

  Future<ShoppingItem> addShoppingItem(String uid, ShoppingItem item) =>
      addShoppingItemForScope(ShoppingScope.personal(uid), item);

  Future<void> deleteShoppingItem(String uid, String itemId) =>
      deleteShoppingItems(uid, [itemId]);

  Future<void> updateShoppingItemForScope(
    ShoppingScope scope,
    ShoppingItem item,
  ) async {
    final id = item.id;
    if (id == null ||
        id.trim().isEmpty ||
        id.contains('/') ||
        id == '.' ||
        id == '..') {
      throw ArgumentError('A saved shopping item needs a valid document ID.');
    }
    if (item.name.trim().isEmpty || item.quantity < 1 || item.quantity > 100) {
      throw ArgumentError('Enter an item name and a quantity from 1 to 100.');
    }
    // update fails if the document was deleted; it must never recreate it.
    await _itemsForScope(
      scope,
    ).doc(id).update(item.copyWith(name: item.name.trim()).toMap());
  }

  Future<void> updateShoppingItem(String uid, ShoppingItem item) =>
      updateShoppingItemForScope(ShoppingScope.personal(uid), item);

  Future<void> deleteShoppingItems(String uid, List<String> itemIds) async {
    return deleteShoppingItemsForScope(ShoppingScope.personal(uid), itemIds);
  }

  Future<void> deleteShoppingItemsForScope(
    ShoppingScope scope,
    List<String> itemIds,
  ) async {
    final collection = _itemsForScope(scope);
    final ids = itemIds.toSet().toList();
    // Validate every ID before committing anything. Never accept document paths.
    if (ids.any(
      (id) => id.trim().isEmpty || id.contains('/') || id == '.' || id == '..',
    )) {
      throw ArgumentError('A shopping item has an invalid document ID.');
    }

    final completed = <String>[];
    try {
      for (var offset = 0; offset < ids.length; offset += _deleteBatchSize) {
        _checkScope(scope);
        final chunk = ids.skip(offset).take(_deleteBatchSize).toList();
        final batch = _firestore.batch();
        for (final id in chunk) {
          batch.delete(collection.doc(id));
        }
        await batch.commit();
        completed.addAll(chunk);
      }
    } catch (error) {
      if (completed.isNotEmpty) {
        throw ShoppingListDeleteException(error, completed);
      }
      rethrow;
    }
  }

  Future<LowStockShoppingWriteResult> createLowStockIfAbsent({
    required ShoppingScope scope,
    required ShoppingItem item,
    required String pantryItemId,
  }) async {
    if (item.id != null ||
        item.source != 'low_stock' ||
        item.sourcePantryItemId != pantryItemId ||
        pantryItemId.trim().isEmpty ||
        pantryItemId.contains('/')) {
      throw ArgumentError('A valid low-stock Pantry item is required.');
    }
    final encoded = base64Url
        .encode(utf8.encode(pantryItemId))
        .replaceAll('=', '');
    final document = _itemsForScope(scope).doc('low-stock-$encoded');
    final savedItem = item.copyWith(name: item.name.trim());
    final result = await _firestore.runTransaction<LowStockShoppingWriteResult>(
      (transaction) async {
        final existing = await transaction.get(document);
        if (existing.exists) {
          return LowStockShoppingWriteResult(
            item: ShoppingItem.fromMap(document.id, existing.data()!),
            created: false,
          );
        }
        transaction.set(document, savedItem.toMap());
        return LowStockShoppingWriteResult(
          item: savedItem.copyWith(id: document.id),
          created: true,
        );
      },
    );
    return result;
  }
}
