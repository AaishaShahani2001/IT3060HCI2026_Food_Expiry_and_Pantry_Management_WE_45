import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/services/expiry_service.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/models/app_notification.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_planner.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_sync.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_time.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';

import 'memory_notification_repository.dart';

void main() {
  final now = DateTime(2026, 10, 2, 12);
  const service = ExpiryService();

  PantryItem item({
    required String id,
    required String name,
    DateTime? expiry,
    double quantity = 4,
    PantryUnit unit = PantryUnit.bottles,
  }) {
    return PantryItem(
      id: id,
      firestoreId: id,
      name: name,
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: quantity,
      unit: unit,
      expiryDate: expiry,
    );
  }

  NotificationPlan plan(
    List<PantryItem> items, {
    Set<String> existingKeys = const {},
    StockMemory memory = const StockMemory(),
  }) {
    return planPantryNotifications(
      items: items,
      existingKeys: existingKeys,
      memory: memory,
      now: now,
      expiryService: service,
    );
  }

  test('formats relative times without storing them', () {
    expect(formatNotificationAge(now, now), 'Just now');
    expect(
      formatNotificationAge(now.subtract(const Duration(seconds: 20)), now),
      'Just now',
    );
    expect(
      formatNotificationAge(now.subtract(const Duration(minutes: 5)), now),
      '5 min ago',
    );
    expect(
      formatNotificationAge(now.subtract(const Duration(hours: 2)), now),
      '2 hr ago',
    );
    expect(formatNotificationAge(DateTime(2026, 10, 1, 18), now), 'Yesterday');
    expect(formatNotificationAge(DateTime(2026, 9, 30, 12), now), '2 days ago');
  });

  test('parses missing and numeric timestamps without throwing', () {
    expect(parseNotificationDate(null), isNull);
    expect(parseNotificationDate(''), isNull);
    expect(parseNotificationDate(double.nan), isNull);
    expect(parseNotificationDate(-1), isNull);
    expect(
      parseNotificationDate(1760000000000),
      DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );

    final parsed = AppNotification.tryParse('expiringSoon_milk_2026-10-03', {
      'userId': 'alice',
      'type': 'expiringSoon',
      'title': 'Milk expires tomorrow',
      'message': 'Use it soon to avoid food waste.',
      'isRead': 'no',
      'createdAt': null,
    });
    expect(parsed, isNotNull);
    expect(parsed!.isRead, isFalse);
    expect(parsed.type, AppNotificationType.expiringSoon);
    expect(parsed.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    expect(AppNotification.tryParse('bad', {'type': 'Expiring soon'}), isNull);
  });

  test('plans expiring, expired, and low-stock copy from pantry status', () {
    final result = plan([
      item(
        id: 'milk',
        name: 'Milk',
        expiry: DateTime(2026, 10, 3),
        quantity: 1,
      ),
      item(
        id: 'chicken',
        name: 'Chicken',
        expiry: DateTime(2026, 10, 4),
        quantity: 3,
      ),
      item(id: 'yogurt', name: 'Yogurt', expiry: DateTime(2026, 9, 28)),
      item(id: 'rice', name: 'Rice', expiry: DateTime(2026, 10, 1)),
    ]);

    final byTitle = {for (final alert in result.create) alert.title: alert};
    expect(
      byTitle['Milk expires tomorrow']!.message,
      'Use it soon to avoid food waste.',
    );
    expect(
      byTitle['Milk expires tomorrow']!.type,
      AppNotificationType.expiringSoon,
    );
    expect(
      byTitle['Milk expires tomorrow']!.alertKey,
      'expiringSoon_milk_2026-10-03',
    );
    expect(
      byTitle['Chicken expires in 2 days']!.message,
      'Plan to use it soon.',
    );
    expect(
      byTitle['Yogurt has expired']!.message,
      'Review the item and record it appropriately.',
    );
    expect(
      byTitle['Rice expired yesterday']!.message,
      'Check whether it should be recorded as waste.',
    );
    expect(byTitle['Milk is running low']!.message, 'Only 1 bottle remains.');
    expect(byTitle['Milk is running low']!.alertKey, 'lowStock_milk_1');
    expect(byTitle.containsKey('Chicken is running low'), isFalse);
  });

  test('does not recreate a dismissed alert or a still-low item', () {
    final milk = item(
      id: 'milk',
      name: 'Milk',
      expiry: DateTime(2026, 10, 3),
      quantity: 1,
    );
    final first = plan([milk]);
    final again = plan(
      [milk],
      existingKeys: {for (final alert in first.create) alert.alertKey},
      memory: first.memory,
    );
    expect(again.create, isEmpty);

    final restocked = plan(
      [
        item(
          id: 'milk',
          name: 'Milk',
          expiry: DateTime(2026, 10, 3),
          quantity: 4,
        ),
      ],
      existingKeys: {for (final alert in first.create) alert.alertKey},
      memory: first.memory,
    );
    expect(restocked.create, isEmpty);
    expect(restocked.memory.armedItemIds, contains('milk'));

    final crossedAgain = plan(
      [milk],
      existingKeys: {for (final alert in first.create) alert.alertKey},
      memory: restocked.memory,
    );
    expect(crossedAgain.create.map((alert) => alert.alertKey), [
      'lowStock_milk_2',
    ]);
  });

  test('a new expiry state can create a new notification', () {
    final soon = plan([
      item(id: 'milk', name: 'Milk', expiry: DateTime(2026, 10, 3)),
    ]);
    final keys = {for (final alert in soon.create) alert.alertKey};
    final moved = plan(
      [item(id: 'milk', name: 'Milk', expiry: DateTime(2026, 10, 8))],
      existingKeys: keys,
      memory: soon.memory,
    );
    expect(moved.create.map((alert) => alert.alertKey), isEmpty);

    final expired = plan(
      [item(id: 'milk', name: 'Milk', expiry: DateTime(2026, 10, 1))],
      existingKeys: keys,
      memory: soon.memory,
    );
    expect(expired.create.single.alertKey, 'expired_milk_2026-10-01');
    expect(expired.create.single.type, AppNotificationType.expired);

    final redated = plan(
      [item(id: 'milk', name: 'Milk', expiry: DateTime(2026, 10, 5))],
      existingKeys: keys,
      memory: soon.memory,
    );
    expect(redated.create.single.alertKey, 'expiringSoon_milk_2026-10-05');
  });

  test('latest five keeps the original list order', () {
    final notifications = [
      for (var index = 0; index < 8; index++)
        AppNotification(
          id: 'n$index',
          userId: 'alice',
          type: AppNotificationType.lowStock,
          title: 'Item $index',
          message: 'Only 1 item remains.',
          alertKey: 'lowStock_item_$index',
          isRead: false,
          createdAt: now.subtract(Duration(minutes: index)),
          deletedAt: index == 1 ? now : null,
        ),
    ];
    final before = notifications
        .map((notification) => notification.id)
        .toList();
    final latest = latestActiveNotifications(notifications);
    expect(
      notifications.map((notification) => notification.id).toList(),
      before,
    );
    expect(latest.map((notification) => notification.id).toList(), [
      'n0',
      'n2',
      'n3',
      'n4',
      'n5',
    ]);
  });

  test('synchronizer writes one alert per event and isolates users', () async {
    final repository = MemoryNotificationRepository();
    final sync = NotificationSynchronizer(
      repository: repository,
      expiryService: service,
      clock: () => now,
    );
    final milk = item(
      id: 'milk',
      name: 'Milk',
      expiry: DateTime(2026, 10, 3),
      quantity: 1,
    );

    await sync.synchronize(userId: 'alice', items: [milk]);
    await sync.synchronize(userId: 'alice', items: [milk]);
    expect(repository.activeOf('alice'), hasLength(2));
    expect(repository.docs['bob'], isNull);

    await sync.synchronize(
      userId: 'bob',
      items: [item(id: 'bread', name: 'Bread', expiry: DateTime(2026, 10, 1))],
    );
    expect(repository.activeOf('bob').single.title, 'Bread expired yesterday');
    expect(
      repository.activeOf('alice').map((notification) => notification.title),
      isNot(contains('Bread expired yesterday')),
    );

    final expiring = repository.docs['alice']!.values.firstWhere(
      (notification) => notification.type == AppNotificationType.expiringSoon,
    );
    await repository.deleteNotification('alice', expiring.id);
    await sync.synchronize(userId: 'alice', items: [milk]);
    expect(
      repository.activeOf('alice').map((notification) => notification.type),
      [AppNotificationType.lowStock],
    );

    await sync.synchronize(
      userId: 'alice',
      items: [
        item(
          id: 'milk',
          name: 'Milk',
          expiry: DateTime(2026, 10, 1),
          quantity: 1,
        ),
      ],
    );
    expect(
      repository.activeOf('alice').map((notification) => notification.type),
      containsAll([AppNotificationType.expired, AppNotificationType.lowStock]),
    );
    expect(
      repository
          .activeOf('alice')
          .where(
            (notification) =>
                notification.type == AppNotificationType.expiringSoon,
          ),
      isEmpty,
    );
  });
}
