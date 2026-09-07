import '../models/pantry_item.dart';

abstract class PantryRepository {
  Future<List<PantryItem>> fetchItems();
  Future<PantryItem> addItem(PantryItem item);
  Future<PantryItem> updateItem(PantryItem item);
  Future<void> deleteItem(String id);
}
