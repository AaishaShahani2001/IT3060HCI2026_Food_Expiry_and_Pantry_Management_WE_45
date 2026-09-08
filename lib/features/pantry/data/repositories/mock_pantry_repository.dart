import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';

class MockPantryRepository implements PantryRepository {
  MockPantryRepository({List<PantryItem>? initialItems})
    : _items = List<PantryItem>.from(initialItems ?? _seedItems);

  final List<PantryItem> _items;
  int _idCounter = 100;

  static final List<PantryItem> _seedItems = [
    PantryItem(
      id: '1',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    PantryItem(
      id: '2',
      name: 'Chicken',
      category: PantryCategory.meat,
      location: PantryLocation.freezer,
      quantity: 2,
      unit: PantryUnit.packs,
      expiryDate: DateTime.now().add(const Duration(days: 14)),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    PantryItem(
      id: '3',
      name: 'Rice',
      category: PantryCategory.grains,
      location: PantryLocation.pantry,
      quantity: 3,
      unit: PantryUnit.kg,
      expiryDate: DateTime.now().add(const Duration(days: 180)),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    PantryItem(
      id: '4',
      name: 'Apples',
      category: PantryCategory.fruits,
      location: PantryLocation.refrigerator,
      quantity: 6,
      unit: PantryUnit.items,
      expiryDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    PantryItem(
      id: '5',
      name: 'Spinach',
      category: PantryCategory.vegetables,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.packs,
      expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    PantryItem(
      id: '6',
      name: 'Olive Oil',
      category: PantryCategory.condiments,
      location: PantryLocation.pantry,
      quantity: 1,
      unit: PantryUnit.bottles,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    PantryItem(
      id: '7',
      name: 'Yogurt',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 0.5,
      unit: PantryUnit.kg,
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    PantryItem(
      id: '8',
      name: 'Frozen Peas',
      category: PantryCategory.vegetables,
      location: PantryLocation.freezer,
      quantity: 1,
      unit: PantryUnit.packs,
      expiryDate: DateTime.now().add(const Duration(days: 90)),
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  @override
  Future<List<PantryItem>> fetchItems() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<PantryItem>.from(_items);
  }

  @override
  Future<PantryItem> addItem(PantryItem item) async {
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
  Future<PantryItem> updateItem(PantryItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      throw StateError('Pantry item not found.');
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
