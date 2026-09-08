import '../../domain/models/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';

class MockShoppingRepository implements ShoppingRepository {
  MockShoppingRepository({List<ShoppingItem>? initialItems})
    : _items = List<ShoppingItem>.from(initialItems ?? _seedItems);

  final List<ShoppingItem> _items;

  int _idCounter = 100;

  static final List<ShoppingItem> _seedItems = [
    ShoppingItem(
      id: '1',
      name: 'Milk',
      quantity: 2,
      unit: 'bottles',
      priority: ShoppingItemPriority.high,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ShoppingItem(
      id: '2',
      name: 'Eggs',
      quantity: 12,
      unit: 'items',
      priority: ShoppingItemPriority.medium,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ShoppingItem(
      id: '3',
      name: 'Bread',
      quantity: 2,
      unit: 'packs',
      priority: ShoppingItemPriority.high,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    ShoppingItem(
      id: '4',
      name: 'Tomatoes',
      quantity: 1,
      unit: 'kg',
      priority: ShoppingItemPriority.medium,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    ShoppingItem(
      id: '5',
      name: 'Cheese',
      quantity: 500,
      unit: 'g',
      priority: ShoppingItemPriority.low,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ShoppingItem(
      id: '6',
      name: 'Cooking Oil',
      quantity: 1,
      unit: 'bottle',
      priority: ShoppingItemPriority.low,
      isCompleted: true,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];

  @override
  Future<List<ShoppingItem>> fetchItems() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return List<ShoppingItem>.from(_items);
  }

  @override
  Future<ShoppingItem> addItem(ShoppingItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final newItem = item.copyWith(
      id: item.id.isEmpty ? '${++_idCounter}' : item.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _items.insert(0, newItem);

    return newItem;
  }

  @override
  Future<ShoppingItem> updateItem(ShoppingItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final index = _items.indexWhere((entry) => entry.id == item.id);

    if (index == -1) {
      throw StateError('Shopping item not found.');
    }

    final updatedItem = item.copyWith(updatedAt: DateTime.now());

    _items[index] = updatedItem;

    return updatedItem;
  }

  @override
  Future<void> deleteItem(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    _items.removeWhere((item) => item.id == id);
  }
}
