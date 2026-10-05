import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/services/expiry_service.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/models/app_notification.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_planner.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_sync.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_time.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/pantry_scope.dart';

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
    expect(parsed.expiryDate, DateTime(2026, 10, 3));
    expect(parsed.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    expect(AppNotification.tryParse('bad', {'type': 'Expiring soon'}), isNull);

    final timed = AppNotification.tryParse(
      'expiringSoon_milk_2026-10-03_1447',
      {
        'userId': 'alice',
        'type': 'expiringSoon',
        'title': 'Milk expires tomorrow',
        'message': 'Use it soon to avoid food waste.',
        'createdAt': null,
      },
    );
    expect(timed?.expiryDate, DateTime(2026, 10, 3, 14, 47));
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

  test('changing only the expiry time creates a fresh reminder event', () {
    final first = plan([
      item(
        id: 'milk',
        name: 'Milk',
        expiry: DateTime(2026, 10, 3, 10, 32),
      ),
    ]);
    final updated = plan(
      [
        item(
          id: 'milk',
          name: 'Milk',
          expiry: DateTime(2026, 10, 3, 18, 15),
        ),
      ],
      existingKeys: {for (final alert in first.create) alert.alertKey},
    );

    expect(first.create.single.alertKey, 'expiringSoon_milk_2026-10-03_1032');
    expect(updated.create.single.alertKey, 'expiringSoon_milk_2026-10-03_1815');
    expect(updated.create.single.expiryDate, DateTime(2026, 10, 3, 18, 15));
  });

  test(
    'planner follows a one-day-before setting instead of the default three days',
    () {
      final result = planPantryNotifications(
        items: [
          item(id: 'grains', name: 'grains', expiry: DateTime(2026, 10, 3)),
          item(id: 'rice', name: 'Rice', expiry: DateTime(2026, 10, 4)),
        ],
        existingKeys: {},
        memory: const StockMemory(),
        now: now,
        expiryService: service,
        expiringSoonDays: 1,
      );
      expect(result.create.single.title, 'grains expires tomorrow');
      expect(result.create.single.expiryDate, DateTime(2026, 10, 3));
    },
  );

  test(
    'changing days-before settings rechecks unchanged pantry items',
    () async {
      var daysBefore = 1;
      final repository = MemoryNotificationRepository();
      final sync = NotificationSynchronizer(
        repository: repository,
        expiryService: service,
        clock: () => now,
        expiringSoonDays: () => daysBefore,
      );
      final grains = item(
        id: 'grains',
        name: 'grains',
        expiry: DateTime(2026, 10, 7),
      );
      await sync.synchronize(userId: 'alice', items: [grains]);
      expect(repository.activeOf('alice'), isEmpty);
      daysBefore = 5;
      await sync.synchronize(userId: 'alice', items: [grains]);
      expect(
        repository.activeOf('alice').single.title,
        'grains expires in 5 days',
      );
    },
  );

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

  test(
    'synchronizer detects expiry on a new day with unchanged pantry items',
    () async {
      var currentTime = now;
      final repository = MemoryNotificationRepository();
      final sync = NotificationSynchronizer(
        repository: repository,
        expiryService: service,
        clock: () => currentTime,
      );
      final milk = item(
        id: 'milk',
        name: 'Milk',
        expiry: DateTime(2026, 10, 2),
      );
      await sync.synchronize(userId: 'alice', items: [milk]);
      expect(
        repository.activeOf('alice').single.type,
        AppNotificationType.expiringSoon,
      );
      currentTime = DateTime(2026, 10, 3, 9);
      await sync.synchronize(userId: 'alice', items: [milk]);
      expect(
        repository.activeOf('alice').map((alert) => alert.type),
        containsAll([
          AppNotificationType.expiringSoon,
          AppNotificationType.expired,
        ]),
      );
    },
  );

  test('personal and shared scopes prefix new alerts without changing the calculation', () {
    final milk = item(
      id: 'milk',
      name: 'Milk',
      expiry: DateTime(2026, 10, 3),
      quantity: 1,
    );
    final personal = plan(
      [milk],
    );
    // The helper above does not pass a scope, so existing wording stays.
    final plain = personal.create.firstWhere(
      (alert) => alert.type == AppNotificationType.expiringSoon,
    );
    expect(plain.title, 'Milk expires tomorrow');
    expect(
      plain.toNotification(userId: 'alice', createdAt: now).displayTitle,
      'Milk expires tomorrow',
    );

    final sharedPlan = planPantryNotifications(
      items: [milk],
      existingKeys: const {},
      memory: const StockMemory(),
      now: now,
      expiryService: service,
      pantryScope: const PantryScope.shared('Smith Home'),
    );
    final sharedExpiry = sharedPlan.create.firstWhere(
      (alert) => alert.type == AppNotificationType.expiringSoon,
    );
    final sharedLow = sharedPlan.create.firstWhere(
      (alert) => alert.type == AppNotificationType.lowStock,
    );
    expect(sharedExpiry.title, 'Milk expires tomorrow');
    expect(sharedExpiry.pantryScope, 'shared');
    expect(sharedExpiry.pantryName, 'Smith Home');
    expect(
      sharedExpiry.toNotification(userId: 'alice', createdAt: now).displayTitle,
      'Smith Home • Milk expires tomorrow',
    );
    expect(
      sharedLow.toNotification(userId: 'alice', createdAt: now).displayTitle,
      'Smith Home • Milk is running low',
    );

    final personalPlan = planPantryNotifications(
      items: [milk],
      existingKeys: const {},
      memory: const StockMemory(),
      now: now,
      expiryService: service,
      pantryScope: const PantryScope.personal(),
    );
    final personalExpiry = personalPlan.create.firstWhere(
      (alert) => alert.type == AppNotificationType.expiringSoon,
    );
    expect(
      personalExpiry
          .toNotification(userId: 'alice', createdAt: now)
          .displayTitle,
      'My Pantry • Milk expires tomorrow',
    );
    expect(
      personalPlan.create
          .firstWhere((alert) => alert.type == AppNotificationType.lowStock)
          .toNotification(userId: 'alice', createdAt: now)
          .displayTitle,
      'My Pantry • Milk is running low',
    );
  });

  test('a missing or unknown pantry scope keeps the stored wording', () {
    final legacy = AppNotification.tryParse('old', {
      'userId': 'alice',
      'type': 'lowStock',
      'title': 'Milk is running low',
      'message': 'Only 1 bottle remains.',
    });
    expect(legacy?.pantryScope, isNull);
    expect(legacy?.displayTitle, 'Milk is running low');

    final unknown = AppNotification.tryParse('odd', {
      'userId': 'alice',
      'type': 'expiringSoon',
      'title': 'Milk expires tomorrow',
      'message': 'Use it soon.',
      'pantryScope': 'office',
    });
    expect(unknown?.pantryScope, isNull);
    expect(unknown?.displayTitle, 'Milk expires tomorrow');

    final stored = AppNotification.tryParse('new', {
      'userId': 'alice',
      'type': 'expired',
      'title': 'Milk has expired',
      'message': 'Review the item and record it appropriately.',
      'pantryScope': 'shared',
      'pantryName': 'Family Home',
    });
    expect(stored?.displayTitle, 'Family Home • Milk has expired');
  });
}
