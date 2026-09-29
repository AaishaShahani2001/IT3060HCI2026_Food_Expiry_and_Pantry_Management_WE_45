class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    this.category = RecipeCategory.other,
    this.preparationTime = 0,
    this.isFavorite = false,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final RecipeCategory category;
  final int preparationTime;
  final bool isFavorite;

  /// Dietary / cuisine tags used by the recommendation engine.
  ///
  /// Examples:
  /// vegetarian
  /// vegan
  /// non-vegetarian
  /// sri lankan
  /// low-carb
  /// high-protein
  final List<String> tags;

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    RecipeCategory? category,
    int? preparationTime,
    bool? isFavorite,
    List<String>? tags,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      category: category ?? this.category,
      preparationTime: preparationTime ?? this.preparationTime,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }
}

enum RecipeCategory {
  breakfast,
  lunch,
  dinner,
  snack,
  dessert,
  other;

  String get label {
    switch (this) {
      case RecipeCategory.breakfast:
        return 'Breakfast';

      case RecipeCategory.lunch:
        return 'Lunch';

      case RecipeCategory.dinner:
        return 'Dinner';

      case RecipeCategory.snack:
        return 'Snack';

      case RecipeCategory.dessert:
        return 'Dessert';

      case RecipeCategory.other:
        return 'Other';
    }
  }
}