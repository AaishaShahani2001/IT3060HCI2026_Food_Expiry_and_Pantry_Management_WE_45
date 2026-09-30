import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/utils/pantry_list_query.dart';

PantryItem _item({
  required String id,
  required String name,
  DateTime? createdAt,
  PantryCategory category = PantryCategory.other,
  PantryLocation location = PantryLocation.pantry,
  double quantity = 2,
}) {
  return PantryItem(
    id: id,
    firestoreId: id,
    name: name,
    category: category,
    location: location,
    quantity: quantity,
    unit: PantryUnit.items,
    createdAt: createdAt,
  );
}

void main() {
  final items = [
    _item(id: '1', name: 'Milk', createdAt: DateTime(2026, 9, 1)),
    _item(id: '2', name: 'Rice', createdAt: DateTime(2026, 9, 10)),
    _item(id: '3', name: 'Apples', createdAt: DateTime(2026, 9, 5)),
    _item(id: '4', name: 'Eggs', createdAt: null),
    _item(
      id: '5',
      name: 'Butter',
      createdAt: DateTime(2026, 9, 8),
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
    ),
    _item(id: '6', name: 'Juice', createdAt: DateTime(2026, 9, 12)),
    _item(
      id: '7',
      name: 'Bread',
      createdAt: DateTime(2026, 9, 3),
      quantity: 0.5,
    ),
  ];

  test('preview never mutates the original filtered list', () {
    final original = List<PantryItem>.from(items);
    final preview = PantryListQuery.preview(items);

    expect(preview, hasLength(5));
    expect(items, hasLength(original.length));
    expect(identical(preview, items), isFalse);
  });

  test('preview returns all items when there are fewer than five', () {
    final few = items.take(3).toList();
    expect(PantryListQuery.preview(few), hasLength(3));
  });

  test('preview returns five items when there are exactly five', () {
    final five = items.take(5).toList();
    expect(PantryListQuery.preview(five), hasLength(5));
  });

  test('recently added sort puts newest createdAt first and nulls last', () {
    final sorted = PantryListQuery.sortItems(
      items,
      PantrySortOption.recentlyAdded,
    );

    expect(sorted.first.name, 'Juice');
    expect(sorted.map((item) => item.name).toList(), [
      'Juice',
      'Rice',
      'Butter',
      'Apples',
      'Bread',
      'Milk',
      'Eggs',
    ]);
  });

  test('selected name sort overrides recently-added default', () {
    final sorted = PantryListQuery.sortItems(items, PantrySortOption.nameAz);
    expect(sorted.first.name, 'Apples');
    expect(sorted.last.name, 'Rice');
  });

  test('search matches item name', () {
    final filtered = PantryListQuery.applyFilters(
      items: items,
      searchQuery: 'milk',
      location: null,
      category: null,
      stockLevel: StockLevelFilter.all,
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'Milk');
  });

  test('search matches category label', () {
    final filtered = PantryListQuery.applyFilters(
      items: items,
      searchQuery: 'dairy',
      location: null,
      category: null,
      stockLevel: StockLevelFilter.all,
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'Butter');
  });

  test('search matches location label', () {
    final filtered = PantryListQuery.applyFilters(
      items: items,
      searchQuery: 'refrigerator',
      location: null,
      category: null,
      stockLevel: StockLevelFilter.all,
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'Butter');
  });

  test('location and category filters can be combined', () {
    final filtered = PantryListQuery.applyFilters(
      items: items,
      searchQuery: '',
      location: PantryLocation.refrigerator,
      category: PantryCategory.dairy,
      stockLevel: StockLevelFilter.all,
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'Butter');
  });
}
