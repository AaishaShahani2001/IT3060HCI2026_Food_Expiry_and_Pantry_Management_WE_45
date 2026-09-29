const List<int> fallbackQuantityPresets = [1, 2, 3, 5];

final List<int> quantityDropdownOptions = List<int>.generate(
  100,
  (index) => index + 1,
  growable: false,
);

const Map<String, List<int>> itemQuantityPresets = {
  'milk': [1, 2, 4, 6],
  'fresh milk': [1, 2, 4, 6],
  'milk powder': [1, 2, 3, 5],
  'eggs': [6, 12, 24, 30],
  'bread': [1, 2, 3, 4],
  'yogurt': [1, 2, 4, 6],
  'rice': [1, 2, 5, 10],
  'chicken': [1, 2, 3, 5],
  'fish': [1, 2, 3, 5],
  'apple': [1, 2, 4, 6],
  'banana': [2, 4, 6, 12],
  'orange': [2, 4, 6, 12],
};

List<int> quantityPresetsFor(String itemName) {
  return itemQuantityPresets[itemName.trim().toLowerCase()] ??
      fallbackQuantityPresets;
}
