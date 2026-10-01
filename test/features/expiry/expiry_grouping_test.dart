import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/services/expiry_service.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';

void main() {
  const service = ExpiryService();
  final today = DateTime(2026, 10, 1);

  PantryItem item(String id, String name, DateTime? expiryDate) {
    return PantryItem(
      id: id,
      name: name,
      category: PantryCategory.other,
      location: PantryLocation.pantry,
      quantity: 1,
      unit: PantryUnit.items,
      expiryDate: expiryDate,
    );
  }

  test('groups calendar days into use first, expiring soon, and expired', () {
    final source = [
      item('later', 'Rice', DateTime(2026, 10, 8)),
      item('soon', 'Beans', DateTime(2026, 10, 4)),
      item('two-days', 'Eggs', DateTime(2026, 10, 3)),
      item('tomorrow', 'Milk', DateTime(2026, 10, 2)),
      item('today', 'Bread', DateTime(2026, 10, 1)),
      item('yesterday', 'Yogurt', DateTime(2026, 9, 30)),
      item('older', 'Cheese', DateTime(2026, 9, 18)),
      item('unknown', 'Salt', null),
    ];

    final groups = service.groupByPriority(source, referenceDate: today);

    expect(groups.useFirst.map((item) => item.name), ['Bread', 'Milk', 'Eggs']);
    expect(groups.expiringSoon.map((item) => item.name), ['Beans']);
    expect(groups.expired.map((item) => item.name), ['Cheese', 'Yogurt']);
    expect(groups.outsidePriority.map((item) => item.name), ['Rice']);
    expect(source.map((item) => item.name).toList(), [
      'Rice',
      'Beans',
      'Eggs',
      'Milk',
      'Bread',
      'Yogurt',
      'Cheese',
      'Salt',
    ]);
  });
}
