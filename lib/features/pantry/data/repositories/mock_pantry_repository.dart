import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';

/// In-memory pantry store used until Firestore reads are connected.
/// Starts empty so the UI never shows sample items.
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
}
