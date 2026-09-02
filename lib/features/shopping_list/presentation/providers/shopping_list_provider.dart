import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

class ShoppingListNotifier extends Notifier<List<ShoppingItem>> {
  @override
  List<ShoppingItem> build() => const [];

  void addItem(ShoppingItem item) {
    state = [...state, item];
  }

  void updateItem(int index, ShoppingItem item) {
    if (!_isValidIndex(index)) return;

    final updatedItems = [...state];
    updatedItems[index] = item;
    state = updatedItems;
  }

  void deleteItem(int index) {
    if (!_isValidIndex(index)) return;

    final updatedItems = [...state]..removeAt(index);
    state = updatedItems;
  }

  void togglePurchased(int index, bool isPurchased) {
    if (!_isValidIndex(index)) return;

    final updatedItems = [...state];
    updatedItems[index] = updatedItems[index].copyWith(
      isPurchased: isPurchased,
    );
    state = updatedItems;
  }

  bool _isValidIndex(int index) => index >= 0 && index < state.length;
}

final shoppingListProvider =
    NotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );
