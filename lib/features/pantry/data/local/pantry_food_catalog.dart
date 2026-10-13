import '../../domain/models/pantry_food_suggestion.dart';
import '../../domain/models/pantry_item.dart';

/// How many suggestion rows the item-name field shows at once.
const int pantryFoodSuggestionLimit = 6;

/// Local household foods used by the Add/Edit Item name field.
///
/// Matching stays in memory so a keystroke never starts a Firestore query.
/// Names the signed-in user already has are merged from the pantry list the
/// screen has already loaded.
///
/// Seafood and frozen foods are mapped onto categories that already exist.
/// This list does not introduce a new [PantryCategory].
const List<PantryFoodSuggestion> pantryFoodCatalog = [
  // Dairy
  PantryFoodSuggestion(
    name: 'Milk',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.liters,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Milk Powder',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Yogurt',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
    keywords: ['yoghurt'],
  ),
  PantryFoodSuggestion(
    name: 'Cheese',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Butter',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Cream',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.ml,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Curd',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  // Ice cream is a frozen food; dairy is the closest existing category.
  PantryFoodSuggestion(
    name: 'Ice Cream',
    category: PantryCategory.dairy,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.freezer,
    keywords: ['icecream'],
  ),

  // Fruits
  PantryFoodSuggestion(
    name: 'Apple',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Banana',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Orange',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Mango',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Grapes',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Strawberry',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Papaya',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Pineapple',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Watermelon',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Avocado',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Lemon',
    category: PantryCategory.fruits,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),

  // Vegetables
  PantryFoodSuggestion(
    name: 'Carrot',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Tomato',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Potato',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Onion',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Cabbage',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Spinach',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Broccoli',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Cucumber',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Beans',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Pumpkin',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Garlic',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Ginger',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Frozen Vegetables',
    category: PantryCategory.vegetables,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.freezer,
  ),

  // Meat. Fish, tuna, salmon, prawns and crab use Meat because there is
  // no Seafood category.
  PantryFoodSuggestion(
    name: 'Chicken',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Beef',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Pork',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Mutton',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Sausages',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Fish',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Tuna',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Salmon',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Prawns',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.freezer,
    keywords: ['shrimp'],
  ),
  PantryFoodSuggestion(
    name: 'Crab',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.freezer,
  ),
  PantryFoodSuggestion(
    name: 'Frozen Chicken',
    category: PantryCategory.meat,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.freezer,
  ),

  // Grains and staples
  PantryFoodSuggestion(
    name: 'Rice',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Red Rice',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Basmati Rice',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Flour',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Bread',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Oats',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Pasta',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Noodles',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Cereal',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Dhal',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
    keywords: ['dal', 'lentils'],
  ),
  PantryFoodSuggestion(
    name: 'Chickpeas',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
    keywords: ['chana'],
  ),
  PantryFoodSuggestion(
    name: 'Millet',
    category: PantryCategory.grains,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),

  // Beverages
  PantryFoodSuggestion(
    name: 'Water',
    category: PantryCategory.beverages,
    defaultUnit: PantryUnit.liters,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Juice',
    category: PantryCategory.beverages,
    defaultUnit: PantryUnit.liters,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Tea',
    category: PantryCategory.beverages,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Coffee',
    category: PantryCategory.beverages,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Soft Drink',
    category: PantryCategory.beverages,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.refrigerator,
    keywords: ['soda', 'cola'],
  ),
  PantryFoodSuggestion(
    name: 'Coconut Water',
    category: PantryCategory.beverages,
    defaultUnit: PantryUnit.ml,
    suggestedLocation: PantryLocation.refrigerator,
  ),

  // Snacks
  PantryFoodSuggestion(
    name: 'Biscuits',
    category: PantryCategory.snacks,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Crackers',
    category: PantryCategory.snacks,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Chocolate',
    category: PantryCategory.snacks,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Chips',
    category: PantryCategory.snacks,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
    keywords: ['crisps'],
  ),
  PantryFoodSuggestion(
    name: 'Nuts',
    category: PantryCategory.snacks,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Popcorn',
    category: PantryCategory.snacks,
    defaultUnit: PantryUnit.packs,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Frozen Pizza',
    category: PantryCategory.snacks,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.freezer,
  ),

  // Condiments, including common pantry staples that share that category.
  PantryFoodSuggestion(
    name: 'Ketchup',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Mayonnaise',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Soy Sauce',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Chilli Sauce',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.pantry,
    keywords: ['chili sauce'],
  ),
  PantryFoodSuggestion(
    name: 'Vinegar',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Jam',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.refrigerator,
  ),
  PantryFoodSuggestion(
    name: 'Honey',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.bottles,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Sugar',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.kg,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Salt',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Spices',
    category: PantryCategory.condiments,
    defaultUnit: PantryUnit.g,
    suggestedLocation: PantryLocation.pantry,
  ),

  // Other
  PantryFoodSuggestion(
    name: 'Eggs',
    category: PantryCategory.other,
    defaultUnit: PantryUnit.items,
    suggestedLocation: PantryLocation.refrigerator,
    keywords: ['egg'],
  ),
  PantryFoodSuggestion(
    name: 'Coconut Milk',
    category: PantryCategory.other,
    defaultUnit: PantryUnit.ml,
    suggestedLocation: PantryLocation.pantry,
  ),
  PantryFoodSuggestion(
    name: 'Cooking Oil',
    category: PantryCategory.other,
    defaultUnit: PantryUnit.liters,
    suggestedLocation: PantryLocation.pantry,
    keywords: ['oil', 'vegetable oil'],
  ),
];

final Set<String> _catalogueNameKeys = {
  for (final suggestion in pantryFoodCatalog)
    normalizeFoodName(suggestion.name),
};

/// Exact catalogue name only.
///
/// Category autofill uses this so a prefix such as "ch" cannot choose Meat
/// while the user might still mean Cheese, Chicken or Chickpeas. A barcode
/// result that has a product name and no category can use the same check;
/// anything other than a full name stays unselected.
PantryFoodSuggestion? exactPantryFoodMatch(String rawName) {
  final normalized = normalizeFoodName(rawName);
  if (normalized.isEmpty) return null;

  for (final suggestion in pantryFoodCatalog) {
    if (normalizeFoodName(suggestion.name) == normalized) {
      return suggestion;
    }
  }
  return null;
}

/// Relevance order: exact name, name prefix, keyword prefix, then contains.
///
/// Catalogue display names win over pantry items that differ only by case,
/// so "Milk" is not listed twice when the user already stored "milk".
List<PantryFoodSuggestion> matchPantryFoodSuggestions(
  String rawQuery, {
  Iterable<PantryItem> existingItems = const [],
  int limit = pantryFoodSuggestionLimit,
}) {
  final query = normalizeFoodName(rawQuery);
  if (query.isEmpty || limit <= 0) return const [];

  final matches = <_RankedFoodSuggestion>[];
  for (final suggestion in pantryFoodCatalog) {
    final rank = _rankFoodSuggestion(suggestion, query);
    if (rank != null) {
      matches.add(_RankedFoodSuggestion(suggestion, rank));
    }
  }

  final seenPantryNames = <String>{};
  for (final item in existingItems) {
    final key = normalizeFoodName(item.name);
    if (key.isEmpty || !seenPantryNames.add(key)) continue;
    if (_catalogueNameKeys.contains(key)) continue;

    final suggestion = PantryFoodSuggestion(
      name: item.name.trim(),
      category: item.category,
    );
    final rank = _rankFoodSuggestion(suggestion, query);
    if (rank != null) {
      matches.add(_RankedFoodSuggestion(suggestion, rank));
    }
  }

  matches.sort((a, b) {
    final byRank = a.rank.index.compareTo(b.rank.index);
    if (byRank != 0) return byRank;
    return normalizeFoodName(
      a.suggestion.name,
    ).compareTo(normalizeFoodName(b.suggestion.name));
  });

  if (matches.length <= limit) {
    return [for (final match in matches) match.suggestion];
  }
  return [for (final match in matches.take(limit)) match.suggestion];
}

/// 1. Exact name. 2. Name starts with the query. 3. Keyword starts with the
/// query. 4. Name or keyword contains the query.
_FoodMatchRank? _rankFoodSuggestion(
  PantryFoodSuggestion suggestion,
  String query,
) {
  final name = normalizeFoodName(suggestion.name);
  if (name.isEmpty) return null;
  if (name == query) return _FoodMatchRank.exact;
  if (name.startsWith(query)) return _FoodMatchRank.namePrefix;

  var keywordContains = false;
  for (final keyword in suggestion.keywords) {
    final normalized = normalizeFoodName(keyword);
    if (normalized.isEmpty) continue;
    if (normalized.startsWith(query)) return _FoodMatchRank.keywordPrefix;
    if (normalized.contains(query)) keywordContains = true;
  }

  if (name.contains(query) || keywordContains) {
    return _FoodMatchRank.contains;
  }
  return null;
}

enum _FoodMatchRank { exact, namePrefix, keywordPrefix, contains }

class _RankedFoodSuggestion {
  const _RankedFoodSuggestion(this.suggestion, this.rank);

  final PantryFoodSuggestion suggestion;
  final _FoodMatchRank rank;
}
