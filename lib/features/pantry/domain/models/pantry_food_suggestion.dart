import 'pantry_item.dart';

/// One known food name and the pantry category it should suggest.
class PantryFoodSuggestion {
  const PantryFoodSuggestion({
    required this.name,
    required this.category,
    this.defaultUnit,
    this.suggestedLocation,
    this.keywords = const [],
  });

  final String name;
  final PantryCategory category;
  final PantryUnit? defaultUnit;
  final PantryLocation? suggestedLocation;

  /// Extra words that should find this item, such as "yoghurt" for Yogurt.
  /// They never count as an exact item name for category autofill.
  final List<String> keywords;
}

/// Trims and lowercases a food name so matching ignores case and spacing.
String normalizeFoodName(String value) {
  return value.trim().toLowerCase();
}
