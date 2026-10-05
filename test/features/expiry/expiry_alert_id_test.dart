import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/expiry_alert_id.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/repositories/expiry_repository.dart';

ExpiryAlert _alert({
  required String id,
  required String userId,
  required String itemId,
}) {
  return ExpiryAlert(
    id: id,
    userId: userId,
    itemId: itemId,
    itemName: 'Milk',
    expiryDate: DateTime(2026, 10, 8),
    daysUntilExpiry: 3,
    status: 'active',
    priority: 'medium',
    message: 'Milk expiry reminder',
    isRead: false,
    createdAt: DateTime(2026, 10, 5),
  );
}

void main() {
  test('shared pantry item gets a separate alert id per user', () {
    expect(buildExpiryAlertId('userA', 'itemX'), 'userA_itemX');
    expect(buildExpiryAlertId('userB', 'itemX'), 'userB_itemX');
    expect(
      buildExpiryAlertId('userA', 'itemX'),
      isNot(buildExpiryAlertId('userB', 'itemX')),
    );
  });

  test('manual alert ids are rewritten off the bare pantry item id', () {
    final scoped = scopedExpiryAlert(
      alert: _alert(id: 'itemX', userId: '', itemId: 'itemX'),
      userId: 'userA',
    );

    expect(scoped.id, 'userA_itemX');
    expect(scoped.userId, 'userA');
    expect(scoped.itemId, 'itemX');
  });

  test('a user-specific alert replaces a legacy item-id alert', () {
    final legacy = _alert(id: 'itemX', userId: 'userA', itemId: 'itemX');
    final canonical = _alert(
      id: 'userA_itemX',
      userId: 'userA',
      itemId: 'itemX',
    );

    final preferred = dedupeExpiryAlerts([legacy, canonical]);

    expect(preferred, hasLength(1));
    expect(preferred.single.id, 'userA_itemX');
  });

  test('different pantry items are both kept', () {
    final alerts = dedupeExpiryAlerts([
      _alert(id: 'userA_milk', userId: 'userA', itemId: 'milk'),
      _alert(id: 'userA_bread', userId: 'userA', itemId: 'bread'),
    ]);

    expect(alerts.map((alert) => alert.id), ['userA_milk', 'userA_bread']);
  });
}
