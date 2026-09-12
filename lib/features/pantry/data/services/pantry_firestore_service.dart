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

/// Cloud Firestore writes for pantry items.
///
/// Path: users/{userId}/pantryItems/{itemId}
/// Reads, quantity +/−, Mark Consumed, and shopping list stay local.
class PantryFirestoreService {
  PantryFirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _itemsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('pantryItems');
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
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('pantryItems')
          .doc(itemId)
          .update({
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
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('pantryItems')
          .doc(itemId)
          .delete();
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry Firestore delete failed: ${error.code} ${error.message}',
      );
      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }
}
