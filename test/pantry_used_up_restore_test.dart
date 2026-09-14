import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/repositories/mock_pantry_repository.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/removed_pantry_item.dart';

PantryItem _milk({required String id, double quantity = 2}) {
  return PantryItem(
    id: id,
    firestoreId: id,
    name: 'Milk',
    category: PantryCategory.dairy,
    location: PantryLocation.refrigerator,
    quantity: quantity,
    unit: PantryUnit.bottles,
    price: 450,
    expiryDate: DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 9, 1),
  );
}

void main() {
  test(
    'Used Up removes the item and Undo restores the same id and fields',
    () async {
      final milk = _milk(id: 'doc-milk');
      final repository = MockPantryRepository(initialItems: [milk]);

      final removed = await repository.markAsUsedUp(milk, originalIndex: 0);

      expect(removed, isA<RemovedPantryItem>());
      expect(removed.documentId, 'doc-milk');
      expect(removed.item.price, 450);
      expect(removed.item.expiryDate, DateTime(2026, 10, 1));
      expect(removed.item.createdAt, DateTime(2026, 9, 1));
      expect(removed.originalQuantity, 2);

      final remaining = await repository.fetchItems();
      expect(remaining, isEmpty);

      final restored = await repository.restoreUsedUpItem(removed);
      expect(restored.id, 'doc-milk');
      expect(restored.firestoreId, 'doc-milk');
      expect(restored.price, 450);
      expect(restored.quantity, 2);
      expect(restored.expiryDate, DateTime(2026, 10, 1));

      final afterRestore = await repository.fetchItems();
      expect(afterRestore.single.id, 'doc-milk');
    },
  );

  test('permanent delete does not restore the item', () async {
    final milk = _milk(id: 'doc-milk');
    final repository = MockPantryRepository(initialItems: [milk]);

    await repository.permanentlyDelete('doc-milk');
    expect(await repository.fetchItems(), isEmpty);
  });

  test('updateQuantity never stores a negative value', () async {
    final milk = _milk(id: 'doc-milk');
    final repository = MockPantryRepository(initialItems: [milk]);

    await repository.updateQuantity(itemId: 'doc-milk', quantity: 5);
    expect((await repository.fetchItems()).single.quantity, 5);

    expect(
      () => repository.updateQuantity(itemId: 'doc-milk', quantity: -1),
      throwsStateError,
    );
  });
}
