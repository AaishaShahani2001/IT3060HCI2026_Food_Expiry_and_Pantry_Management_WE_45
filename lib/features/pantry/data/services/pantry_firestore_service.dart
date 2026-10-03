import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/pantry_item.dart';
import '../../domain/models/removed_pantry_item.dart';
import '../../../shared_pantry/data/shared_pantry_service.dart';

/// User-facing Firestore error. [toString] is the friendly message only.
class PantryFirestoreException implements Exception {
  const PantryFirestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The pantry document for [itemId] was not found in the active pantry.
class PantryItemNotFoundException extends PantryFirestoreException {
  const PantryItemNotFoundException(this.itemId)
    : super('This item no longer exists.');

  final String itemId;
}

/// [amount] or the stored quantity cannot be used for a decrement.
class InvalidPantryQuantityException extends PantryFirestoreException {
  const InvalidPantryQuantityException(super.message);
}

/// [requested] is greater than the quantity stored for the item.
class InsufficientPantryQuantityException extends PantryFirestoreException {
  const InsufficientPantryQuantityException({
    required this.requested,
    required this.available,
  }) : super('The requested amount is greater than the available quantity.');

  final double requested;
  final double available;
}

/// The signed-in user cannot change the selected Personal or Shared Pantry.
class PantryAccessDeniedException extends PantryFirestoreException {
  const PantryAccessDeniedException([
    super.message = 'You do not have permission to update this item.',
  ]);
}

/// Pantry quantities are stored to two decimal places, matching
/// [PantryFirestoreService.updateQuantity]. Values that round to 0.00 become
/// 0 so an exact depletion is not left as a floating-point residue.
double _normalizePantryQuantity(double value) {
  final normalized = double.parse(value.toStringAsFixed(2));
  return normalized == 0 ? 0.0 : normalized;
}

double _readStoredQuantity(Map<String, dynamic>? data) {
  final raw = data == null ? null : data['quantity'];
  if (raw is! num) {
    throw const InvalidPantryQuantityException(
      'The stored quantity is missing or invalid.',
    );
  }

  final value = raw.toDouble();
  if (!value.isFinite || value < 0) {
    throw const InvalidPantryQuantityException(
      'The stored quantity is missing or invalid.',
    );
  }

  return _normalizePantryQuantity(value);
}

double _validatedDecrement(double amount) {
  if (!amount.isFinite) {
    throw const InvalidPantryQuantityException(
      'The decrement amount must be a finite number greater than zero.',
    );
  }

  final normalized = _normalizePantryQuantity(amount);
  if (normalized <= 0) {
    throw const InvalidPantryQuantityException(
      'The decrement amount must be greater than zero.',
    );
  }

  return normalized;
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

const String kPantrySignInRequiredMessage =
    'Please sign in again to manage your pantry.';

String _friendlyFirebaseMessage(String code) {
  switch (code) {
    case 'unauthenticated':
      return kPantrySignInRequiredMessage;
    case 'permission-denied':
      return 'You do not have permission to modify this item.';
    case 'not-found':
      return 'This item no longer exists.';
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

/// Cloud Firestore operations for pantry items.
///
/// Personal:
/// users/{userId}/pantryItems/{itemId}
///
/// Family / Hostel / Shared:
/// pantries/{pantryId}/items/{itemId}
class PantryFirestoreService {
  PantryFirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? Function()? currentUserId,
    Future<ActivePantryContext> Function()? activePantryContext,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? (currentUserId == null ? FirebaseAuth.instance : null),
       _currentUserId = currentUserId,
       _activePantryContext =
           activePantryContext ??
           SharedPantryService.instance.getActivePantryContext;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  /// When set, used instead of [FirebaseAuth.currentUser]. Tests pass this so
  /// they do not initialize Firebase Auth.
  final String? Function()? _currentUserId;

  /// Defaults to [SharedPantryService.instance.getActivePantryContext].
  final Future<ActivePantryContext> Function() _activePantryContext;

  String? _signedInUserId() {
    final currentUserId = _currentUserId;
    if (currentUserId != null) return currentUserId();
    return _auth?.currentUser?.uid;
  }

  /// Returns the correct pantry item collection.
  ///
  /// Personal:
  /// users/{uid}/pantryItems
  ///
  /// Family / Shared:
  /// pantries/{pantryId}/items
  Future<CollectionReference<Map<String, dynamic>>> _itemsCollection() async {
    final uid = _signedInUserId();

    if (uid == null || uid.isEmpty) {
      throw const PantryFirestoreException(kPantrySignInRequiredMessage);
    }

    final context = await _activePantryContext();
    return _collectionFor(uid, context);
  }

  CollectionReference<Map<String, dynamic>> _collectionFor(
    String uid,
    ActivePantryContext context,
  ) {
    if (context.pantryType == 'personal') {
      return _firestore.collection('users').doc(uid).collection('pantryItems');
    }

    if ((context.pantryType == 'family' || context.pantryType == 'shared') &&
        context.pantryId != null &&
        context.pantryId!.isNotEmpty) {
      return _firestore
          .collection('pantries')
          .doc(context.pantryId)
          .collection('items');
    }

    throw const PantryFirestoreException(
      'No active pantry is available. Please create or join a shared pantry.',
    );
  }

  /// Shared and family pantries keep membership at
  /// pantries/{pantryId}/members/{uid}, written by [SharedPantryService].
  Future<void> _requireSharedMember(
    String uid,
    ActivePantryContext context,
  ) async {
    final isShared =
        context.pantryType == 'family' || context.pantryType == 'shared';
    if (!isShared) return;

    final pantryId = context.pantryId;
    if (pantryId == null || pantryId.isEmpty) {
      throw const PantryFirestoreException(
        'No active pantry is available. Please create or join a shared pantry.',
      );
    }

    final memberSnapshot = await _firestore
        .collection('pantries')
        .doc(pantryId)
        .collection('members')
        .doc(uid)
        .get();
    final memberUid = memberSnapshot.data()?['uid'];
    if (!memberSnapshot.exists || memberUid != uid) {
      throw const PantryAccessDeniedException(
        'You do not have permission to update this shared pantry.',
      );
    }
  }

  /// Returns a specific pantry item document.
  Future<DocumentReference<Map<String, dynamic>>> _itemDoc({
    required String itemId,
  }) async {
    final collection = await _itemsCollection();
    return collection.doc(itemId);
  }

  /// Live list of the active pantry's items.
  Stream<List<PantryItem>> watchPantryItems({required String userId}) {
    late final StreamController<List<PantryItem>> controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;

    controller = StreamController<List<PantryItem>>(
      onListen: () async {
        try {
          final collection = await _itemsCollection();

          subscription = collection.snapshots().listen(
            (snapshot) {
              final items = <PantryItem>[];

              for (final document in snapshot.docs) {
                try {
                  items.add(
                    PantryItem.fromFirestore(document.id, document.data()),
                  );
                } catch (error, stackTrace) {
                  debugPrint(
                    'Skipping pantry document '
                    '${document.id}: $error',
                  );
                  debugPrint('$stackTrace');
                }
              }

              items.sort((a, b) {
                final aDate =
                    a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bDate =
                    b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

                return bDate.compareTo(aDate);
              });

              if (!controller.isClosed) {
                controller.add(items);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Pantry watch failed: $error');
              debugPrint('$stackTrace');

              if (!controller.isClosed) {
                controller.addError(
                  PantryFirestoreException(mapPantryLoadError(error)),
                  stackTrace,
                );
              }
            },
          );
        } catch (error, stackTrace) {
          debugPrint('Pantry watch setup failed: $error');
          debugPrint('$stackTrace');

          if (!controller.isClosed) {
            controller.addError(
              PantryFirestoreException(mapPantryLoadError(error)),
              stackTrace,
            );
          }
        }
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Creates a new document and returns the item with
  /// [PantryItem.firestoreId] set.
  ///
  /// Uses a pre-assigned ID when [item] already has one so the photo upload
  /// and this Firestore document share the same item ID.
  Future<PantryItem> addItem(PantryItem item) async {
    final uid = _signedInUserId();

    if (uid == null || uid.isEmpty) {
      throw const PantryFirestoreException(kPantrySignInRequiredMessage);
    }

    final now = DateTime.now();
    final itemData = item.toFirestore(userId: uid);

    final providedId = (item.firestoreId ?? item.id).trim();

    final itemId = providedId.isNotEmpty ? providedId : newItemDocumentId(uid);

    try {
      final itemReference = await _itemDoc(itemId: itemId);

      await itemReference.set(itemData);

      return item.copyWith(
        id: itemId,
        firestoreId: itemId,
        createdAt: item.createdAt ?? now,
        updatedAt: now,
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry Firestore add failed: '
        '${error.code} ${error.message}',
      );

      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }

  /// Firestore document ID generated before a photo upload, so the pantry
  /// document and the saved image metadata use the same item ID.
  String newItemDocumentId(String userId) {
    return _firestore.collection('_pantryItemIds').doc().id;
  }

  /// Removes [item] because it was consumed. The Firestore document is deleted
  /// using its current ID so Undo can recreate the same document.
  ///
  /// Photos stay in Cloudinary or legacy Storage during Used Up so Undo can
  /// restore photoUrl, imagePublicId, and imageProvider. This client does not
  /// delete the remote file.
  Future<RemovedPantryItem> markAsUsedUp({
    required String userId,
    required PantryItem item,
    required int originalIndex,
  }) async {
    final itemId = item.firestoreId ?? item.id;

    if (itemId.trim().isEmpty) {
      throw const PantryFirestoreException(
        'This item is local-only and is not connected to Firestore yet.',
      );
    }

    await deletePantryItem(userId: userId, itemId: itemId);

    return RemovedPantryItem(item: item, originalIndex: originalIndex);
  }

  /// Restores a Used Up item with the same document ID.
  Future<void> restoreUsedUpItem({
    required String userId,
    required RemovedPantryItem removedItem,
  }) async {
    final itemId = removedItem.documentId;

    if (itemId.trim().isEmpty) {
      throw PantryFirestoreException(
        'Unable to restore ${removedItem.name}. Please try again.',
      );
    }

    try {
      final itemReference = await _itemDoc(itemId: itemId);

      await itemReference.set(
        removedItem.item.toFirestore(userId: userId, preserveCreatedAt: true),
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry Used Up restore failed: '
        '${error.code} ${error.message}',
      );

      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }

  /// Writes the remaining quantity only. Original quantity and price stay put.
  Future<void> updateQuantity({
    required String userId,
    required String itemId,
    required double quantity,
  }) async {
    if (quantity < 0) {
      throw const PantryFirestoreException('Quantity cannot be negative.');
    }

    try {
      final itemReference = await _itemDoc(itemId: itemId);

      await itemReference.update({
        'quantity': double.parse(quantity.toStringAsFixed(2)),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry quantity update failed: '
        '${error.code} ${error.message}',
      );

      throw PantryFirestoreException(
        _friendlyQuantityFirebaseMessage(error.code),
      );
    }
  }

  /// Updates an existing pantry document.
  Future<void> updatePantryItem({
    required String userId,
    required String itemId,
    required PantryItem item,
  }) async {
    try {
      final itemReference = await _itemDoc(itemId: itemId);

      await itemReference.update({
        'name': item.name,
        'category': item.category.name,
        'location': item.location.name,
        'quantity': item.quantity,
        'originalQuantity': item.originalQuantity,
        'unit': item.unit.name,
        'priceType': item.priceType.name,
        'priceAmount': item.priceAmount,
        'price': item.priceAmount,
        'expiryDate': item.expiryDate == null
            ? null
            : Timestamp.fromDate(item.expiryDate!),
        'photoUrl': item.hasUserPhoto ? item.photoUrl : FieldValue.delete(),
        'photoStoragePath': item.hasUserPhoto && item.photoStoragePath != null
            ? item.photoStoragePath
            : FieldValue.delete(),
        'imagePublicId': item.hasUserPhoto && item.imagePublicId != null
            ? item.imagePublicId
            : FieldValue.delete(),
        'imageProvider': item.hasUserPhoto && item.imageProvider != null
            ? item.imageProvider
            : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry Firestore update failed: '
        '${error.code} ${error.message}',
      );

      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }

  /// Deletes only the given pantry item document.
  Future<void> deletePantryItem({
    required String userId,
    required String itemId,
  }) async {
    try {
      final itemReference = await _itemDoc(itemId: itemId);

      await itemReference.delete();
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry Firestore delete failed: '
        '${error.code} ${error.message}',
      );

      throw PantryFirestoreException(_friendlyFirebaseMessage(error.code));
    }
  }

  /// Adds [change] to quantity.
  Future<double> changeItemQuantity({
    required String userId,
    required String itemId,
    required double change,
  }) async {
    try {
      final reference = await _itemDoc(itemId: itemId);

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
        'Pantry quantity change failed: '
        '${error.code} ${error.message}',
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

  /// Subtracts [consumedQuantity] from stock.
  Future<double> markItemConsumed({
    required String userId,
    required String itemId,
    required double consumedQuantity,
  }) async {
    try {
      if (consumedQuantity <= 0) {
        throw ArgumentError('invalid-consumed-quantity');
      }

      final reference = await _itemDoc(itemId: itemId);

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
      debugPrint(
        'Pantry mark consumed failed: '
        '${error.code} ${error.message}',
      );

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

  /// Decreases the active pantry item's quantity by [amount] inside a
  /// Firestore transaction.
  ///
  /// The transaction reads the latest stored quantity, so a concurrent edit is
  /// retried instead of overwritten. Zero is written on the same document.
  /// This does not delete the item, mark it used up, or create a waste record.
  /// A waste record written separately is not atomic with this update.
  Future<double> decrementItemQuantity({
    required String userId,
    required String itemId,
    required double amount,
  }) async {
    try {
      final uid = _signedInUserId();
      if (uid == null || uid.isEmpty) {
        throw const PantryFirestoreException(kPantrySignInRequiredMessage);
      }
      if (userId != uid) {
        throw const PantryAccessDeniedException();
      }
      if (itemId.trim().isEmpty) {
        throw PantryItemNotFoundException(itemId);
      }

      final context = await _activePantryContext();
      final itemRef = _collectionFor(uid, context).doc(itemId);
      await _requireSharedMember(uid, context);

      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(itemRef);
        if (!snapshot.exists) {
          throw PantryItemNotFoundException(itemId);
        }

        final currentQuantity = _readStoredQuantity(snapshot.data());
        final decrement = _validatedDecrement(amount);
        if (decrement > currentQuantity) {
          throw InsufficientPantryQuantityException(
            requested: decrement,
            available: currentQuantity,
          );
        }

        final newQuantity = _normalizePantryQuantity(
          currentQuantity - decrement,
        );
        transaction.update(itemRef, {
          'quantity': newQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return newQuantity;
      });
    } on PantryFirestoreException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'Pantry quantity decrement failed: '
        '${error.code} ${error.message}',
      );

      throw PantryFirestoreException(
        _friendlyQuantityFirebaseMessage(error.code),
      );
    }
  }
}
