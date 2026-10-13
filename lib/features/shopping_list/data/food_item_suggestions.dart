const Map<String, List<String>> foodItemSuggestionCategories = {
  'Dairy': [
    'Milk',
    'Fresh Milk',
    'Full Cream Milk',
    'Low Fat Milk',
    'Skim Milk',
    'Milk Powder',
    'Condensed Milk',
    'Evaporated Milk',
    'Coconut Milk',
    'Cheese',
    'Cheddar Cheese',
    'Mozzarella',
    'Parmesan',
    'Cream Cheese',
    'Butter',
    'Margarine',
    'Yogurt',
    'Greek Yogurt',
    'Curd',
    'Buffalo Curd',
    'Cream',
    'Whipping Cream',
    'Sour Cream',
    'Paneer',
  ],
  'Bakery': [
    'Bread',
    'White Bread',
    'Brown Bread',
    'Whole Wheat Bread',
    'Sandwich Bread',
    'Garlic Bread',
    'Buns',
    'Burger Buns',
    'Hot Dog Buns',
    'Croissant',
    'Cake',
    'Cupcake',
    'Muffin',
    'Doughnut',
    'Cookies',
    'Biscuits',
    'Crackers',
  ],
  'Rice, Grains and Cereals': [
    'Rice',
    'White Rice',
    'Red Rice',
    'Basmati Rice',
    'Samba Rice',
    'Nadu Rice',
    'Brown Rice',
    'Jasmine Rice',
    'Parboiled Rice',
    'Oats',
    'Cereal',
    'Corn Flakes',
    'Wheat',
    'Barley',
    'Millet',
    'Quinoa',
    'Semolina',
    'Flour',
    'Wheat Flour',
    'Rice Flour',
    'Corn Flour',
    'Gram Flour',
  ],
  'Pasta and Noodles': [
    'Pasta',
    'Spaghetti',
    'Macaroni',
    'Penne',
    'Noodles',
    'Instant Noodles',
    'Rice Noodles',
  ],
  'Vegetables': [
    'Tomato',
    'Potato',
    'Onion',
    'Red Onion',
    'Spring Onion',
    'Garlic',
    'Ginger',
    'Carrot',
    'Cabbage',
    'Cauliflower',
    'Broccoli',
    'Beans',
    'Green Beans',
    'Pumpkin',
    'Cucumber',
    'Eggplant',
    'Brinjal',
    'Capsicum',
    'Bell Pepper',
    'Chili',
    'Green Chili',
    'Leeks',
    'Beetroot',
    'Radish',
    'Spinach',
    'Lettuce',
    'Mushroom',
    'Sweet Potato',
    'Corn',
    'Peas',
    'Okra',
    'Bitter Gourd',
    'Drumstick',
  ],
  'Fruits': [
    'Apple',
    'Banana',
    'Mango',
    'Orange',
    'Grapes',
    'Pineapple',
    'Papaya',
    'Watermelon',
    'Melon',
    'Guava',
    'Avocado',
    'Strawberry',
    'Blueberry',
    'Raspberry',
    'Kiwi',
    'Pear',
    'Peach',
    'Plum',
    'Pomegranate',
    'Lemon',
    'Lime',
    'Coconut',
    'Passion Fruit',
    'Dragon Fruit',
    'Dates',
    'Rambutan',
    'Wood Apple',
  ],
  'Meat': [
    'Chicken',
    'Chicken Breast',
    'Chicken Thigh',
    'Chicken Wings',
    'Whole Chicken',
    'Beef',
    'Minced Beef',
    'Pork',
    'Mutton',
    'Lamb',
    'Sausages',
    'Bacon',
    'Ham',
    'Meatballs',
  ],
  'Seafood': [
    'Fish',
    'Tuna',
    'Salmon',
    'Sardines',
    'Mackerel',
    'Prawns',
    'Shrimp',
    'Crab',
    'Cuttlefish',
    'Squid',
    'Anchovies',
    'Fish Fillet',
  ],
  'Eggs': ['Eggs', 'Chicken Eggs', 'Quail Eggs'],
  'Frozen Food': [
    'Frozen Chicken',
    'Frozen Fish',
    'Frozen Vegetables',
    'Frozen Peas',
    'Frozen French Fries',
    'Frozen Pizza',
    'Frozen Berries',
    'Ice Cream',
  ],
  'Canned and Packaged Food': [
    'Canned Tuna',
    'Canned Fish',
    'Canned Beans',
    'Baked Beans',
    'Canned Corn',
    'Canned Tomatoes',
    'Canned Chickpeas',
    'Soup',
    'Instant Soup',
    'Packet Soup',
  ],
  'Spices and Condiments': [
    'Salt',
    'Sugar',
    'Brown Sugar',
    'Pepper',
    'Black Pepper',
    'Chili Powder',
    'Curry Powder',
    'Turmeric',
    'Cinnamon',
    'Cardamom',
    'Cloves',
    'Cumin',
    'Coriander Powder',
    'Mustard',
    'Mustard Seeds',
    'Ketchup',
    'Tomato Sauce',
    'Chilli Sauce',
    'Soy Sauce',
    'Fish Sauce',
    'Mayonnaise',
    'Vinegar',
    'Pickles',
    'Jam',
    'Honey',
    'Spices',
  ],
  'Oils': [
    'Coconut Oil',
    'Vegetable Oil',
    'Olive Oil',
    'Sunflower Oil',
    'Sesame Oil',
    'Canola Oil',
    'Corn Oil',
    'Cooking Oil',
  ],
  'Beverages': [
    'Water',
    'Bottled Water',
    'Sparkling Water',
    'Tea',
    'Green Tea',
    'Black Tea',
    'Coffee',
    'Instant Coffee',
    'Juice',
    'Orange Juice',
    'Apple Juice',
    'Mango Juice',
    'Soft Drink',
    'Energy Drink',
    'Sports Drink',
    'Hot Chocolate',
    'Malt Drink',
    'Coconut Water',
  ],
  'Snacks': [
    'Chips',
    'Potato Chips',
    'Chocolate',
    'Candy',
    'Nuts',
    'Peanuts',
    'Cashews',
    'Almonds',
    'Popcorn',
    'Pretzels',
    'Wafer Biscuits',
    'Snack Bars',
  ],
  'Legumes': [
    'Lentils',
    'Red Lentils',
    'Green Gram',
    'Chickpeas',
    'Kidney Beans',
    'Cowpea',
    'Dhal',
    'Black Gram',
    'Soya Beans',
  ],
  'Breakfast': ['Granola', 'Muesli', 'Peanut Butter', 'Pancake Mix'],
  'Baking': [
    'Baking Powder',
    'Baking Soda',
    'Yeast',
    'Cocoa Powder',
    'Vanilla Essence',
    'Icing Sugar',
    'Gelatin',
  ],
  'Plant-Based Food': [
    'Tofu',
    'Tempeh',
    'Soya Meat',
    'Soy Milk',
    'Almond Milk',
    'Oat Milk',
  ],
  'Cooking Essentials': [
    'Coconut Cream',
    'Stock Cubes',
    'Chicken Stock',
    'Vegetable Stock',
    'Breadcrumbs',
    'Desiccated Coconut',
    'Tamarind',
    'Curry Leaves',
  ],
};

final List<String> foodItemSuggestions = _buildFoodItemSuggestions();

final Map<String, String> _canonicalFoodNameByNormalized = Map.unmodifiable({
  for (final name in foodItemSuggestions) normalizeFoodItemName(name): name,
});

// Derived from the autocomplete catalogue, not a second food list.
final Map<String, String> _categoryByFoodName = Map.unmodifiable({
  for (final category in foodItemSuggestionCategories.entries)
    for (final name in category.value) name.trim().toLowerCase(): category.key,
});

const Map<String, String> _canonicalNameByAlias = {
  'chili sauce': 'Chilli Sauce',
  'soda': 'Soft Drink',
};

String normalizeFoodItemName(String value) => value.trim().toLowerCase();

String? canonicalFoodItemNameFor(String name) {
  final normalized = normalizeFoodItemName(name);
  final alias = _canonicalNameByAlias[normalized];
  return alias ?? _canonicalFoodNameByNormalized[normalized];
}

String foodItemCategoryFor(String name) {
  final canonical = canonicalFoodItemNameFor(name);
  return canonical == null
      ? 'Other'
      : _categoryByFoodName[normalizeFoodItemName(canonical)] ?? 'Other';
}

/// Case-insensitive Shopping autocomplete ordered by exact, full-name prefix,
/// word prefix, alias prefix, then contains.
List<String> matchFoodItemSuggestions(String rawQuery, {int? limit}) {
  final query = normalizeFoodItemName(rawQuery);
  if (query.isEmpty || (limit != null && limit <= 0)) return const [];

  final aliasesByCanonical = <String, List<String>>{};
  for (final alias in _canonicalNameByAlias.entries) {
    aliasesByCanonical
        .putIfAbsent(normalizeFoodItemName(alias.value), () => [])
        .add(alias.key);
  }

  final matches = <({String name, int rank})>[];
  for (final name in foodItemSuggestions) {
    final normalizedName = normalizeFoodItemName(name);
    final aliases = aliasesByCanonical[normalizedName] ?? const <String>[];
    final rank = _foodMatchRank(normalizedName, aliases, query);
    if (rank != null) matches.add((name: name, rank: rank));
  }

  matches.sort((first, second) {
    final byRank = first.rank.compareTo(second.rank);
    if (byRank != 0) return byRank;
    return normalizeFoodItemName(
      first.name,
    ).compareTo(normalizeFoodItemName(second.name));
  });

  final names = matches.map((match) => match.name);
  return List.unmodifiable(limit == null ? names : names.take(limit));
}

int? _foodMatchRank(String name, List<String> aliases, String query) {
  if (name == query) return 0;
  if (name.startsWith(query)) return 1;
  if (name.split(' ').skip(1).any((word) => word.startsWith(query))) return 2;
  if (aliases.any((alias) => alias.startsWith(query))) return 3;
  if (name.contains(query) || aliases.any((alias) => alias.contains(query))) {
    return 4;
  }
  return null;
}

List<String> _buildFoodItemSuggestions() {
  final suggestionsByName = <String, String>{};

  for (final items in foodItemSuggestionCategories.values) {
    for (final item in items) {
      suggestionsByName.putIfAbsent(item.toLowerCase(), () => item);
    }
  }

  final suggestions = suggestionsByName.values.toList()
    ..sort((first, second) {
      return normalizeFoodItemName(
        first,
      ).compareTo(normalizeFoodItemName(second));
    });

  return List.unmodifiable(suggestions);
}
