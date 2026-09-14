import '../models/pantry_item.dart';

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
}
