import 'pantry_item.dart';

/// Snapshot used to restore a pantry item after Used Up Undo.
///
/// Keeps the complete [PantryItem] (including Firestore document ID, quantity,
/// createdAt, and every other model field) plus its visible-list index.
class RemovedPantryItem {
  const RemovedPantryItem({required this.item, required this.originalIndex});

  final PantryItem item;
  final int originalIndex;

  String get documentId {
    final firestoreId = item.firestoreId;
    if (firestoreId != null && firestoreId.trim().isNotEmpty) {
      return firestoreId;
    }
    return item.id;
  }

  String get name => item.name;

  double get originalQuantity => item.quantity;
}
