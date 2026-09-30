import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_item_metadata.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/low_stock_suggestion_settings.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_pantry_provider.dart';

PantryItem pantryItem({
  required String id,
  required String name,
  required double quantity,
  PantryUnit unit = PantryUnit.items,
  PantryCategory category = PantryCategory.other,
}) {
  return PantryItem(
    id: id,
    firestoreId: id,
    name: name,
    category: category,
    location: PantryLocation.pantry,
    quantity: quantity,
    unit: unit,
  );
}

void main() {
  test('old shopping documents load with safe unit and category defaults', () {
    final item = ShoppingItem.fromMap('old', {
      'name': 'Milk',
      'quantity': 2,
      'isPurchased': false,
    });
    expect(item.unit, PantryUnit.items);
    expect(item.category, 'Other');
    expect(resolvedShoppingCategory(item), 'Dairy');
  });

  test('low-stock suggestions exclude every existing shopping-list match', () {
    final suggestions = lowStockShoppingSuggestions(
      pantryItems: [
        pantryItem(id: 'milk', name: 'Milk', quantity: 1),
        pantryItem(id: 'eggs', name: 'Eggs', quantity: 1),
        pantryItem(id: 'rice', name: 'Rice', quantity: 4),
      ],
      shoppingItems: const [ShoppingItem(name: ' milk ', quantity: 1)],
    );
    expect(suggestions.map((item) => item.name), ['Eggs']);
  });

  test('low-stock suggestions exclude dismissed pantry item IDs', () {
    final suggestions = lowStockShoppingSuggestions(
      pantryItems: [
        pantryItem(id: 'milk', name: 'Milk', quantity: 1),
        pantryItem(id: 'eggs', name: 'Eggs', quantity: 1),
      ],
      shoppingItems: const [],
      dismissedPantryItemIds: const {'milk'},
    );
    expect(suggestions.map((item) => item.name), ['Eggs']);
  });

  test('category thresholds apply independently and immediately', () {
    final pantryItems = [
      pantryItem(
        id: 'milk',
        name: 'Milk',
        quantity: 2,
        category: PantryCategory.dairy,
      ),
      pantryItem(
        id: 'apple',
        name: 'Apple',
        quantity: 2,
        category: PantryCategory.fruits,
      ),
    ];
    final dairyOnly = lowStockShoppingSuggestions(
      pantryItems: pantryItems,
      shoppingItems: const [],
      categoryThresholds: const {
        PantryCategory.dairy: 2,
        PantryCategory.fruits: 1,
      },
    );
    expect(dairyOnly.map((item) => item.name), ['Milk']);

    final fruitOnly = lowStockShoppingSuggestions(
      pantryItems: pantryItems,
      shoppingItems: const [],
      categoryThresholds: const {
        PantryCategory.dairy: 1,
        PantryCategory.fruits: 2,
      },
    );
    expect(fruitOnly.map((item) => item.name), ['Apple']);
  });

  test('disabled low-stock suggestions return no items', () {
    final suggestions = lowStockShoppingSuggestions(
      pantryItems: [pantryItem(id: 'milk', name: 'Milk', quantity: 0)],
      shoppingItems: const [],
      enabled: false,
      categoryThresholds: const {PantryCategory.other: 100},
    );
    expect(suggestions, isEmpty);
  });

  test('default category level preserves 100 g/ml low-stock behavior', () {
    final suggestions = lowStockShoppingSuggestions(
      pantryItems: [
        pantryItem(
          id: 'flour',
          name: 'Flour',
          quantity: 100,
          unit: PantryUnit.g,
          category: PantryCategory.grains,
        ),
        pantryItem(
          id: 'oil',
          name: 'Oil',
          quantity: 101,
          unit: PantryUnit.ml,
          category: PantryCategory.condiments,
        ),
      ],
      shoppingItems: const [],
      categoryThresholds: defaultLowStockThresholds,
    );
    expect(suggestions.map((item) => item.name), ['Flour']);
  });

  test('quick picks prefer frequent/current names and keep safe fallbacks', () {
    final picks = shoppingQuickPicks(const [
      ShoppingItem(name: 'Tea', quantity: 1),
      ShoppingItem(name: 'Milk', quantity: 1),
      ShoppingItem(name: 'Tea', quantity: 2, isPurchased: true),
    ]);
    expect(picks.first, 'Tea');
    expect(picks, containsAll(['Milk', 'Eggs', 'Bread', 'Rice']));
  });

  test('pantry metadata maps into shopping and back without a classifier', () {
    final milk = pantryItem(
      id: 'milk',
      name: 'Milk',
      quantity: 1,
      unit: PantryUnit.liters,
      category: PantryCategory.dairy,
    );
    expect(shoppingCategoryForPantryItem(milk), 'Dairy');
    expect(pantryCategoryForShoppingCategory('Dairy'), PantryCategory.dairy);
    expect(shoppingUnitLabel(PantryUnit.liters), 'L');
  });
}
