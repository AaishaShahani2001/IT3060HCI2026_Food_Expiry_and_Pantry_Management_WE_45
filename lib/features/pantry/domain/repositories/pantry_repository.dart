import '../models/pantry_item.dart';
import '../models/removed_pantry_item.dart';

abstract class PantryRepository {
  Future<List<PantryItem>> fetchItems();
  Future<PantryItem> addItem(PantryItem item);
  Future<PantryItem> updateItem(PantryItem item);
  Future<void> deleteItem(String id);

  /// Returns the first item whose name matches [name] (trimmed, case-insensitive).
  ///
  /// Pass [excludeItemId] when editing so the item being saved is not treated
  /// as its own duplicate. Structured for a later Firestore query swap.
  PantryItem? findDuplicateByName(String name, {String? excludeItemId});

  /// Removes [item] because it was consumed and returns restoration data.
  Future<RemovedPantryItem> markAsUsedUp(
    PantryItem item, {
    required int originalIndex,
  });

  /// Recreates the Used Up item using its original id and fields.
  Future<PantryItem> restoreUsedUpItem(RemovedPantryItem removedItem);

  /// Permanently deletes an item. No restoration snapshot is kept.
  Future<void> permanentlyDelete(String id);

  /// Writes an absolute quantity for [itemId]. Never stores a negative value.
  Future<void> updateQuantity({
    required String itemId,
    required double quantity,
  });
}
