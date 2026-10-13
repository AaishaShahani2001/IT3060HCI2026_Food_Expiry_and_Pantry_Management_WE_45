import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/repositories/mock_pantry_repository.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';

void main() {
  test('constructor stores the entered price', () {
    final item = PantryItem(
      id: '1',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      price: 450,
    );

    expect(item.price, 450);
    expect(item.priceLabel, 'Rs. 450.00');
  });

  test('copyWith preserves price when other fields change', () {
    final item = PantryItem(
      id: '',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      price: 450,
    );

    final copied = item.copyWith(
      id: '101',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    expect(copied.price, 450);
  });

  test('quantity adjustment preserves price', () {
    final item = PantryItem(
      id: '1',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      price: 450,
    );

    expect(item.withAdjustedQuantity(1).price, 450);
  });

  test('mock repository addItem preserves price', () async {
    final repository = MockPantryRepository(initialItems: const []);
    final created = await repository.addItem(
      PantryItem(
        id: '',
        name: 'Milk',
        category: PantryCategory.dairy,
        location: PantryLocation.refrigerator,
        quantity: 1,
        unit: PantryUnit.bottles,
        price: 450,
      ),
    );

    expect(created.price, 450);
  });
}
