import '../models/shopping_item.dart';

abstract class ShoppingRepository {
  Future<List<ShoppingItem>> fetchItems();

  Future<ShoppingItem> addItem(ShoppingItem item);

  Future<ShoppingItem> updateItem(ShoppingItem item);

  Future<void> deleteItem(String id);
}
