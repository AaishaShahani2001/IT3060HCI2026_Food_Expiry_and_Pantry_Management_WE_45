import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

class ShoppingListRepository {
  final List<ShoppingItem> _items = [];

  List<ShoppingItem> getShoppingItems() => List.unmodifiable(_items);

  List<ShoppingItem> addShoppingItem(ShoppingItem item) {
    _items.add(item);
    return getShoppingItems();
  }

  List<ShoppingItem> updateShoppingItem(int index, ShoppingItem item) {
    if (_isValidIndex(index)) {
      _items[index] = item;
    }

    return getShoppingItems();
  }

  List<ShoppingItem> deleteShoppingItem(int index) {
    if (_isValidIndex(index)) {
      _items.removeAt(index);
    }

    return getShoppingItems();
  }

  List<ShoppingItem> togglePurchased(int index, bool isPurchased) {
    if (_isValidIndex(index)) {
      _items[index] = _items[index].copyWith(isPurchased: isPurchased);
    }

    return getShoppingItems();
  }

  bool _isValidIndex(int index) => index >= 0 && index < _items.length;
}
