import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_expiry_and_pantry_management/core/services/auth_service.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ?? (() => AuthService.instance.currentUser?.uid);

  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;
  static const _deleteBatchSize = 400;

  bool isCurrentUser(String uid) =>
      uid.isNotEmpty && !uid.contains('/') && _currentUid() == uid;

  void _checkUser(String uid) {
    if (!isCurrentUser(uid)) {
      throw StateError('Your account changed. Please sign in and try again.');
    }
  }

  CollectionReference<Map<String, dynamic>> _items(String uid) {
    _checkUser(uid);
    return _firestore.collection('users').doc(uid).collection('shopping_items');
  }

  Future<List<ShoppingItem>> getShoppingItems(String uid) async {
    final snapshot = await _items(uid).get();
    _checkUser(uid);
    return snapshot.docs
        .map((document) => ShoppingItem.fromMap(document.id, document.data()))
        .toList();
  }

  Future<ShoppingItem> addShoppingItem(String uid, ShoppingItem item) async {
    if (item.id != null) {
      throw ArgumentError('Only a new item can be saved.');
    }
    if (item.name.trim().isEmpty || item.quantity < 1 || item.quantity > 100) {
      throw ArgumentError('Enter an item name and a quantity from 1 to 100.');
    }
    final savedItem = item.copyWith(name: item.name.trim());
    final document = await _items(uid).add(savedItem.toMap());
    return savedItem.copyWith(id: document.id);
  }

  Future<void> deleteShoppingItem(String uid, String itemId) =>
      deleteShoppingItems(uid, [itemId]);

  Future<void> deleteShoppingItems(String uid, List<String> itemIds) async {
    final collection = _items(uid);
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
        _checkUser(uid);
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
}
