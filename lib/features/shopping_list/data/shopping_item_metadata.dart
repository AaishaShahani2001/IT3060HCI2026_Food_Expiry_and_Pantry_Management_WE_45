import '../../pantry/domain/models/pantry_item.dart';
import '../models/shopping_item.dart';
import 'food_item_suggestions.dart';

const List<String> shoppingUnitLabels = ['pcs', 'kg', 'g', 'L', 'ml'];

const List<PantryUnit> shoppingUnits = [
  PantryUnit.items,
  PantryUnit.kg,
  PantryUnit.g,
  PantryUnit.liters,
  PantryUnit.ml,
];

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
