import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/food_item_suggestions.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_item_metadata.dart';

void main() {
  test('Shopping catalogue includes useful Pantry-reference foods once', () {
    expect(foodItemSuggestions, hasLength(275));
    expect(
      foodItemSuggestions.map(normalizeFoodItemName).toSet(),
      hasLength(foodItemSuggestions.length),
    );

    // Former Pantry-only entries.
    expect(foodItemSuggestions, containsAll(['Coconut Water', 'Cooking Oil']));
    expect(foodItemSuggestions, containsAll(['Chilli Sauce', 'Spices']));

    // Former Shopping-only entries.
    expect(foodItemSuggestions, containsAll(['Rice Flour', 'Rice Noodles']));
    expect(foodItemSuggestions, containsAll(['Cheddar Cheese', 'Quinoa']));
  });

  test('matching is case-insensitive with prefix results before contains', () {
    const expected = [
      'Rice',
      'Rice Flour',
      'Rice Noodles',
      'Basmati Rice',
      'Brown Rice',
      'Jasmine Rice',
      'Nadu Rice',
      'Parboiled Rice',
      'Red Rice',
      'Samba Rice',
      'White Rice',
    ];

    expect(matchFoodItemSuggestions('ri').take(expected.length), expected);
    expect(matchFoodItemSuggestions('  RI  ').take(expected.length), expected);
    expect(matchFoodItemSuggestions('chili'), contains('Chilli Sauce'));
  });

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
    expect(foodItemCategoryFor('Chili Sauce'), 'Spices and Condiments');
    expect(foodItemCategoryFor('Rice Flour'), 'Rice, Grains and Cereals');
    expect(foodItemCategoryFor('Sri Lankan Red Rice'), 'Other');
    expect(foodItemCategoryFor('Mil'), 'Other');
    expect(foodItemCategoryFor(''), 'Other');
  });

  test('known foods expose canonical names and Shopping default units', () {
    expect(canonicalFoodItemNameFor('  RICE  '), 'Rice');
    expect(canonicalFoodItemNameFor('soda'), 'Soft Drink');
    expect(shoppingDefaultUnitForFood('Rice')?.name, 'kg');
    expect(shoppingDefaultUnitForFood('Basmati Rice')?.name, 'kg');
    expect(shoppingDefaultUnitForFood('Rice Flour')?.name, 'kg');
    expect(shoppingDefaultUnitForFood('Rice Noodles')?.name, 'packs');
    expect(shoppingDefaultUnitForFood('Milk')?.name, 'liters');
    expect(shoppingDefaultUnitForFood('Biscuits')?.name, 'packs');
    expect(shoppingDefaultUnitForFood('Prawns')?.name, 'kg');
    expect(shoppingDefaultUnitForFood('Soft Drink')?.name, 'bottles');
    expect(shoppingDefaultUnitForFood('Unknown custom item'), isNull);
  });
}
