import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>(
  (ref) => ShoppingListRepository(),
);

class ShoppingListNotifier extends Notifier<List<ShoppingItem>> {
  ShoppingListRepository get _repository =>
      ref.read(shoppingListRepositoryProvider);

  @override
  List<ShoppingItem> build() => _repository.getShoppingItems();

  void addItem(ShoppingItem item) {
    state = _repository.addShoppingItem(item);
  }

  void updateItem(int index, ShoppingItem item) {
    state = _repository.updateShoppingItem(index, item);
  }

  void deleteItem(int index) {
    state = _repository.deleteShoppingItem(index);
  }

  void togglePurchased(int index, bool isPurchased) {
    state = _repository.togglePurchased(index, isPurchased);
  }
}

final shoppingListProvider =
    NotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );
