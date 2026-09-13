import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/pantry_item.dart';

/// User-facing Firestore error. [toString] is the friendly message only.
class PantryFirestoreException implements Exception {
  const PantryFirestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Maps technical Firebase/unknown errors to the messages shown in the UI.
String mapPantryFirestoreError(Object error) {
  if (error is PantryFirestoreException) {
    return error.message;
  }

  if (error is FirebaseException) {
    debugPrint('Pantry Firestore error: ${error.code} ${error.message}');
    return _friendlyFirebaseMessage(error.code);
  }

  debugPrint('Pantry Firestore error: $error');
  return 'Something went wrong. Please try again.';
}

/// Friendly messages for Pantry list/stream load failures.
String mapPantryLoadError(Object error) {
  if (error is PantryFirestoreException) {
    return error.message;
  }

  if (error is FirebaseException) {
    debugPrint('Pantry load error: ${error.code} ${error.message}');
    switch (error.code) {
      case 'unauthenticated':
        return 'Please log in to view your Pantry.';
      case 'permission-denied':
        return 'You do not have permission to view these items.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'Unable to load items. Check your connection and try again.';
      default:
        return 'Something went wrong while loading your Pantry.';
    }
  }

  debugPrint('Pantry load error: $error');
  return 'Something went wrong while loading your Pantry.';
}

String _friendlyFirebaseMessage(String code) {
  switch (code) {
    case 'permission-denied':
      return 'You do not have permission to modify this item.';
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
      return 'Unable to connect. Check your internet connection and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

String _friendlyQuantityFirebaseMessage(String code) {
  switch (code) {
    case 'permission-denied':
      return 'You do not have permission to update this item.';
    case 'not-found':
      return 'This item no longer exists.';
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
      return 'Unable to update the item. Check your connection and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

PantryFirestoreException _quantityFailure(Object error) {
  final text = error.toString();
  if (text.contains('item-not-found')) {
    return const PantryFirestoreException('This item no longer exists.');
  }
  if (text.contains('insufficient-quantity')) {
    return const PantryFirestoreException(
      'The available quantity has changed. Please try again.',
    );
  }
  if (text.contains('invalid-consumed-quantity')) {
    return const PantryFirestoreException('Enter a quantity greater than 0.');
  }
  return const PantryFirestoreException(
    'Something went wrong. Please try again.',
  );
}

/// Cloud Firestore writes for pantry items.
///
/// Path: users/{userId}/pantryItems/{itemId}
class PantryFirestoreService {
  PantryFirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _itemsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('pantryItems');
  }

  DocumentReference<Map<String, dynamic>> _itemDoc({
    required String userId,
    required String itemId,
  }) {
    return _itemsCollection(userId).doc(itemId);
  }

  /// Live list of the signed-in user's pantry items.
  /// Sorted in memory so documents without createdAt still appear.
  Stream<List<PantryItem>> watchPantryItems({required String userId}) {
    return _itemsCollection(userId)
        .snapshots()
        .map((snapshot) {
          final items = <PantryItem>[];
          for (final document in snapshot.docs) {
            try {
              items.add(PantryItem.fromFirestore(document.id, document.data()));
            } catch (error, stackTrace) {
              debugPrint('Skipping pantry document ${document.id}: $error');
              debugPrint('$stackTrace');
            }
          }
          items.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return items;
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('Pantry watch failed: $error');
          debugPrint('$stackTrace');
          throw PantryFirestoreException(mapPantryLoadError(error));
        });
  }

  /// Creates a new document and returns the item with [PantryItem.firestoreId] set.
  Future<PantryItem> addItem(PantryItem item) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PantryFirestoreException('Please log in before continuing.');
    }

    final now = DateTime.now();
    final itemData = <String, dynamic>{
      'name': item.name,
      'category': item.category.name,
      'location': item.location.name,
      'quantity': item.quantity,
      'unit': item.unit.name,
      'price': item.unitPrice,
      'expiryDate': item.expiryDate == null
          ? null
          : Timestamp.fromDate(item.expiryDate!),
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      // Let Firestore generate the document ID. Never use the item name.
      final document = await _itemsCollection(user.uid).add(itemData);

      return item.copyWith(
        id: document.id,
        firestoreId: document.id,
        createdAt: item.createdAt ?? now,
        updatedAt: now,
      );
    } on FirebaseException catch (error) {
      debugPrint('Pantry Firestore add failed: ${error.code} ${error.message}');
      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }

  /// Updates an existing pantry document. Does not change [createdAt].
  ///
  /// Field names match [PantryItem]: location (not storageLocation),
  /// nullable expiryDate, no purchaseDate/barcode/image on this model.
  Future<void> updatePantryItem({
    required String userId,
    required String itemId,
    required PantryItem item,
  }) async {
    try {
      await _itemDoc(userId: userId, itemId: itemId).update({
        'name': item.name,
        'category': item.category.name,
        'location': item.location.name,
        'quantity': item.quantity,
        'unit': item.unit.name,
        'price': item.unitPrice,
        'expiryDate': item.expiryDate == null
            ? null
            : Timestamp.fromDate(item.expiryDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry Firestore update failed: ${error.code} ${error.message}',
      );
      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }

  /// Deletes only the given pantry item document. Never deletes the user doc.
  Future<void> deletePantryItem({
    required String userId,
    required String itemId,
  }) async {
    try {
      await _itemDoc(userId: userId, itemId: itemId).delete();
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry Firestore delete failed: ${error.code} ${error.message}',
      );
      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }

  /// Adds [change] to quantity. Only [quantity] and [updatedAt] change.
  ///
  /// Uses get + update instead of runTransaction. Client transactions open a
  /// platform EventChannel whose `cancel` method is missing on Windows/desktop
  /// (MissingPluginException). Rapid taps are still blocked in the provider.
  ///
  /// [change] uses the item's real step size (1, 0.5, or 50) because quantity
  /// is a [double] on [PantryItem].
  Future<double> changeItemQuantity({
    required String userId,
    required String itemId,
    required double change,
  }) async {
    final reference = _itemDoc(userId: userId, itemId: itemId);

    try {
      final snapshot = await reference.get();
      if (!snapshot.exists) {
        throw StateError('item-not-found');
      }

      final currentQuantity =
          (snapshot.data()?['quantity'] as num?)?.toDouble() ?? 0;
      final newQuantity = double.parse(
        (currentQuantity + change).toStringAsFixed(2),
      );

      if (newQuantity < 0) {
        throw StateError('insufficient-quantity');
      }

      await reference.update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return newQuantity;
    } on PantryFirestoreException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry quantity change failed: ${error.code} ${error.message}',
      );
      final text = '${error.code} ${error.message}';
      if (text.contains('item-not-found') ||
          text.contains('insufficient-quantity')) {
        throw _quantityFailure(error);
      }
      throw PantryFirestoreException(
        _friendlyQuantityFirebaseMessage(error.code),
      );
    } catch (error) {
      debugPrint('Pantry quantity change failed: $error');
      throw _quantityFailure(error);
    }
  }

  /// Subtracts [consumedQuantity] from stock. Keeps quantity 0.
  ///
  /// Same get + update path as [changeItemQuantity] to avoid the Windows
  /// transaction EventChannel crash.
  Future<double> markItemConsumed({
    required String userId,
    required String itemId,
    required double consumedQuantity,
  }) async {
    final reference = _itemDoc(userId: userId, itemId: itemId);

    try {
      if (consumedQuantity <= 0) {
        throw ArgumentError('invalid-consumed-quantity');
      }

      final snapshot = await reference.get();
      if (!snapshot.exists) {
        throw StateError('item-not-found');
      }

      final currentQuantity =
          (snapshot.data()?['quantity'] as num?)?.toDouble() ?? 0;

      if (consumedQuantity > currentQuantity) {
        throw StateError('insufficient-quantity');
      }

      final remainingQuantity = double.parse(
        (currentQuantity - consumedQuantity).toStringAsFixed(2),
      );

      await reference.update({
        'quantity': remainingQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return remainingQuantity;
    } on PantryFirestoreException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint('Pantry mark consumed failed: ${error.code} ${error.message}');
      final text = '${error.code} ${error.message}';
      if (text.contains('item-not-found') ||
          text.contains('insufficient-quantity') ||
          text.contains('invalid-consumed-quantity')) {
        throw _quantityFailure(error);
      }
      throw PantryFirestoreException(
        _friendlyQuantityFirebaseMessage(error.code),
      );
    } catch (error) {
      debugPrint('Pantry mark consumed failed: $error');
      throw _quantityFailure(error);
    }
  }
}
