import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/food_item_suggestions.dart';

void main() {
  test('category lookup reuses every catalogue entry', () {
    for (final category in foodItemSuggestionCategories.entries) {
      for (final name in category.value) {
        expect(foodItemCategoryFor('  ${name.toUpperCase()}  '), category.key);
      }
    }
  });

  test('custom and partial names remain Other', () {
    expect(foodItemCategoryFor('Milk'), 'Dairy');
    expect(foodItemCategoryFor('Bread'), 'Bakery');
    expect(foodItemCategoryFor('Sri Lankan Red Rice'), 'Other');
    expect(foodItemCategoryFor('Mil'), 'Other');
    expect(foodItemCategoryFor(''), 'Other');
  });
}
