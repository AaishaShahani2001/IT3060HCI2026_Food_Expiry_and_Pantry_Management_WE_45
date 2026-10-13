import '../../domain/models/pantry_item.dart';
import '../../domain/models/removed_pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';
import '../../domain/utils/pantry_duplicate_lookup.dart';

/// Optional in-memory pantry store used by unit tests.
class MockPantryRepository implements PantryRepository {
  MockPantryRepository({List<PantryItem>? initialItems})
    : _items = List<PantryItem>.from(initialItems ?? const []);

  final List<PantryItem> _items;
  int _idCounter = 100;

  @override
  Future<List<PantryItem>> fetchItems() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<PantryItem>.from(_items);
  }

  @override
  Future<PantryItem> addItem(PantryItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // copyWith keeps firestoreId so Firestore-backed items stay linked.
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

  @override
  PantryItem? findDuplicateByName(String name, {String? excludeItemId}) {
    return lookupDuplicatePantryItemByName(
      _items,
      name,
      excludeItemId: excludeItemId,
    );
  }

  @override
  Future<RemovedPantryItem> markAsUsedUp(
    PantryItem item, {
    required int originalIndex,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      throw StateError('Pantry item not found.');
    }
    final snapshot = _items[index];
    _items.removeAt(index);
    return RemovedPantryItem(
      item: snapshot,
      originalIndex: originalIndex >= 0 ? originalIndex : index,
    );
  }

  @override
  Future<PantryItem> restoreUsedUpItem(RemovedPantryItem removedItem) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final existingIndex = _items.indexWhere(
      (entry) => entry.id == removedItem.item.id,
    );
    if (existingIndex != -1) {
      return _items[existingIndex];
    }

    final insertAt = removedItem.originalIndex.clamp(0, _items.length);
    _items.insert(insertAt, removedItem.item);
    return removedItem.item;
  }

  @override
  Future<void> permanentlyDelete(String id) => deleteItem(id);

  @override
  Future<void> updateQuantity({
    required String itemId,
    required double quantity,
  }) async {
    if (quantity < 0) {
      throw StateError('Quantity cannot be negative.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _items.indexWhere((entry) => entry.id == itemId);
    if (index == -1) {
      throw StateError('Pantry item not found.');
    }
    _items[index] = _items[index].copyWith(
      quantity: double.parse(quantity.toStringAsFixed(2)),
      updatedAt: DateTime.now(),
    );
  }
}
