import '../../pantry/domain/models/pantry_item.dart';
import '../models/shopping_item.dart';
import 'food_item_suggestions.dart';

const List<String> shoppingUnitLabels = [
  'pcs',
  'kg',
  'g',
  'L',
  'ml',
  'packs',
  'bottles',
];

const List<PantryUnit> shoppingUnits = [
  PantryUnit.items,
  PantryUnit.kg,
  PantryUnit.g,
  PantryUnit.liters,
  PantryUnit.ml,
  PantryUnit.packs,
  PantryUnit.bottles,
];

const Set<String> _literFoodNames = {
  'milk',
  'fresh milk',
  'full cream milk',
  'low fat milk',
  'skim milk',
  'coconut milk',
  'soy milk',
  'almond milk',
  'oat milk',
};

const Set<String> _bottledFoodNames = {
  'water',
  'bottled water',
  'sparkling water',
  'juice',
  'orange juice',
  'apple juice',
  'mango juice',
  'soft drink',
  'energy drink',
  'sports drink',
  'coconut water',
  'ketchup',
  'tomato sauce',
  'chilli sauce',
  'soy sauce',
  'fish sauce',
  'mayonnaise',
  'vinegar',
  'coconut oil',
  'vegetable oil',
  'olive oil',
  'sunflower oil',
  'sesame oil',
  'canola oil',
  'corn oil',
  'cooking oil',
};

const Set<String> _packedFoodNames = {
  'bread',
  'white bread',
  'brown bread',
  'whole wheat bread',
  'sandwich bread',
  'garlic bread',
  'biscuits',
  'cookies',
  'crackers',
  'wafer biscuits',
};

PantryUnit? shoppingDefaultUnitForFood(String name) {
  final canonical = canonicalFoodItemNameFor(name);
  if (canonical == null) return null;

  final normalized = normalizeFoodItemName(canonical);
  if (_literFoodNames.contains(normalized)) return PantryUnit.liters;
  if (_bottledFoodNames.contains(normalized)) return PantryUnit.bottles;
  if (_packedFoodNames.contains(normalized)) return PantryUnit.packs;

  return switch (foodItemCategoryFor(canonical)) {
    'Rice, Grains and Cereals' ||
    'Meat' ||
    'Seafood' ||
    'Legumes' => PantryUnit.kg,
    'Pasta and Noodles' ||
    'Frozen Food' ||
    'Canned and Packaged Food' ||
    'Snacks' ||
    'Breakfast' ||
    'Baking' => PantryUnit.packs,
    _ => PantryUnit.items,
  };
}

String shoppingUnitLabel(PantryUnit unit) => switch (unit) {
  PantryUnit.items => 'pcs',
  PantryUnit.kg => 'kg',
  PantryUnit.g => 'g',
  PantryUnit.liters => 'L',
  PantryUnit.ml => 'ml',
  PantryUnit.packs => 'packs',
  PantryUnit.bottles => 'bottles',
  PantryUnit.boxes => 'boxes',
};

String shoppingCategoryForPantryItem(PantryItem item) {
  final catalogueCategory = foodItemCategoryFor(item.name);
  if (catalogueCategory != 'Other') return catalogueCategory;
  return switch (item.category) {
    PantryCategory.dairy => 'Dairy',
    PantryCategory.meat => 'Meat',
    PantryCategory.grains => 'Rice, Grains and Cereals',
    PantryCategory.fruits => 'Fruits',
    PantryCategory.vegetables => 'Vegetables',
    PantryCategory.beverages => 'Beverages',
    PantryCategory.snacks => 'Snacks',
    PantryCategory.condiments => 'Spices and Condiments',
    PantryCategory.other => 'Other',
  };
}

String resolvedShoppingCategory(ShoppingItem item) {
  if (item.category.trim().isNotEmpty && item.category != 'Other') {
    return item.category;
  }
  return foodItemCategoryFor(item.name);
}

PantryCategory pantryCategoryForShoppingCategory(String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized == 'dairy') return PantryCategory.dairy;
  if (normalized == 'meat' || normalized == 'seafood') {
    return PantryCategory.meat;
  }
  if (normalized == 'fruits') return PantryCategory.fruits;
  if (normalized == 'vegetables') return PantryCategory.vegetables;
  if (normalized == 'beverages') return PantryCategory.beverages;
  if (normalized == 'snacks') return PantryCategory.snacks;
  if (normalized == 'spices and condiments' ||
      normalized == 'cooking essentials') {
    return PantryCategory.condiments;
  }
  if (normalized.contains('grain') ||
      normalized == 'bakery' ||
      normalized == 'pasta and noodles' ||
      normalized == 'breakfast' ||
      normalized == 'baking') {
    return PantryCategory.grains;
  }
  return PantryCategory.other;
}

List<String> shoppingQuickPicks(Iterable<ShoppingItem> items, {int limit = 6}) {
  const fallback = ['Milk', 'Eggs', 'Bread', 'Rice'];
  final counts = <String, int>{};
  final labels = <String, String>{};
  final lastSeen = <String, int>{};
  var index = 0;
  for (final item in items) {
    final normalized = item.name.trim().toLowerCase();
    if (normalized.isEmpty) continue;
    counts[normalized] = (counts[normalized] ?? 0) + 1;
    labels[normalized] = item.name.trim();
    lastSeen[normalized] = index++;
  }
  final ranked = counts.keys.toList()
    ..sort((a, b) {
      final byFrequency = counts[b]!.compareTo(counts[a]!);
      if (byFrequency != 0) return byFrequency;
      return lastSeen[b]!.compareTo(lastSeen[a]!);
    });
  final result = <String>[for (final key in ranked) labels[key]!];
  for (final name in fallback) {
    if (!result.any((value) => value.toLowerCase() == name.toLowerCase())) {
      result.add(name);
    }
  }
  return result.take(limit).toList(growable: false);
}
