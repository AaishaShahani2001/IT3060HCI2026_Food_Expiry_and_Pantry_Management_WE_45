import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/models/app_notification.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/presentation/providers/notification_providers.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/presentation/widgets/notification_bell.dart';

import 'memory_notification_repository.dart';

void main() {
  final clock = DateTime(2026, 10, 2, 12);

  AppNotification note({
    required String id,
    required String title,
    String message = 'Use it soon to avoid food waste.',
    String userId = 'alice',
    AppNotificationType type = AppNotificationType.expiringSoon,
    bool isRead = false,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      pantryItemId: id,
      pantryItemName: title,
      alertKey: id,
      isRead: isRead,
      createdAt: createdAt ?? clock.subtract(const Duration(minutes: 5)),
    );
  }

  Future<StreamController<String?>> pumpBell(
    WidgetTester tester, {
    required MemoryNotificationRepository repository,
    String? uid = 'alice',
    Size size = const Size(400, 800),
    ThemeData? theme,
    double scale = 1,
    Widget? navigation,
  }) async {
    final uids = StreamController<String?>.broadcast();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
          notificationUserIdProvider.overrideWith((ref) => uids.stream),
          notificationClockProvider.overrideWithValue(() => clock),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: const Align(
              alignment: Alignment.topRight,
              child: NotificationBell(),
            ),
            bottomNavigationBar: navigation,
          ),
        ),
      ),
    );
    if (uid != null) uids.add(uid);
    await tester.pump();
    await tester.pump();
    return uids;
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
  }

  testWidgets('bell hides the badge when nothing is unread', (tester) async {
    final repository = MemoryNotificationRepository();
    repository.seed(
      note(id: 'read', title: 'Milk expires tomorrow', isRead: true),
    );
    await pumpBell(tester, repository: repository);

    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
  });

  testWidgets('bell shows the unread count and 9+ past nine', (tester) async {
    final repository = MemoryNotificationRepository();
    repository.seed(note(id: 'a', title: 'Milk expires tomorrow'));
    repository.seed(
      note(
        id: 'b',
        title: 'Yogurt has expired',
        type: AppNotificationType.expired,
        message: 'Review the item and record it appropriately.',
        createdAt: clock.subtract(const Duration(hours: 2)),
      ),
    );
    await pumpBell(tester, repository: repository);

    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);

    for (var index = 0; index < 8; index++) {
      repository.seed(
        note(
          id: 'extra$index',
          title: 'Extra $index',
          createdAt: clock.subtract(Duration(minutes: index + 3)),
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications, 10 unread'), findsOneWidget);
  });

  testWidgets('panel shows the latest five newest first', (tester) async {
    final repository = MemoryNotificationRepository();
    for (var index = 0; index < 6; index++) {
      repository.seed(
        note(
          id: 'n$index',
          title: index == 5 ? 'Hidden oats' : 'Alert $index',
          createdAt: clock.subtract(Duration(days: index)),
        ),
      );
    }
    await pumpBell(tester, repository: repository);
    await openPanel(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('Latest updates from your pantry'), findsOneWidget);
    expect(find.text('Hidden oats'), findsNothing);
    expect(find.text('Alert 0'), findsOneWidget);
    expect(find.text('Alert 1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alert 0')).dy,
      lessThan(tester.getTopLeft(find.text('Alert 1')).dy),
    );
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('5 min ago'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Alert 4'),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Alert 4'), findsOneWidget);
    expect(find.text('Hidden oats'), findsNothing);
  });

  testWidgets('shows expiring, expired, and low-stock rows', (tester) async {
    final repository = MemoryNotificationRepository();
    repository.seed(note(id: 'soon', title: 'Milk expires tomorrow'));
    repository.seed(
      note(
        id: 'expired',
        title: 'Yogurt has expired',
        type: AppNotificationType.expired,
        message: 'Review the item and record it appropriately.',
        createdAt: clock.subtract(const Duration(hours: 2)),
      ),
    );
    repository.seed(
      note(
        id: 'low',
        title: 'Milk is running low',
        type: AppNotificationType.lowStock,
        message: 'Only 1 bottle remains.',
        createdAt: clock.subtract(const Duration(minutes: 1)),
      ),
    );
    await pumpBell(tester, repository: repository);
    await openPanel(tester);

    expect(find.text('Milk expires tomorrow'), findsOneWidget);
    expect(find.text('Use it soon to avoid food waste.'), findsOneWidget);
    expect(find.text('Yogurt has expired'), findsOneWidget);
    expect(find.text('Milk is running low'), findsOneWidget);
    expect(find.text('Only 1 bottle remains.'), findsOneWidget);
    expect(find.text('5 min ago'), findsOneWidget);
    expect(find.text('2 hr ago'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread-soon')),
      findsOneWidget,
    );
  });

  testWidgets('tapping an unread row marks it read and can mark it unread', (
    tester,
  ) async {
    final repository = MemoryNotificationRepository();
    repository.seed(note(id: 'soon', title: 'Milk expires tomorrow'));
    await pumpBell(tester, repository: repository);
    await openPanel(tester);

    await tester.tap(find.text('Milk expires tomorrow'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-unread-soon')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
    expect(repository.docs['alice']!['soon']!.isRead, isTrue);
    expect(find.text('Notifications'), findsWidgets);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.byTooltip('Notification actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-unread-soon')),
      findsOneWidget,
    );
    expect(repository.docs['alice']!['soon']!.isRead, isFalse);
    expect(find.text('2'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('mark all reads every notification, including hidden ones', (
    tester,
  ) async {
    final repository = MemoryNotificationRepository();
    for (var index = 0; index < 6; index++) {
      repository.seed(
        note(
          id: 'n$index',
          title: 'Alert $index',
          createdAt: clock.subtract(Duration(minutes: index)),
        ),
      );
    }
    await pumpBell(tester, repository: repository);
    await openPanel(tester);
    expect(find.text('Alert 5'), findsNothing);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();

    expect(
      repository.docs['alice']!.values.every(
        (notification) => notification.isRead,
      ),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
    expect(find.text('All notifications marked as read.'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('deleting one notification updates the list and the badge', (
    tester,
  ) async {
    final repository = MemoryNotificationRepository();
    repository.seed(note(id: 'soon', title: 'Milk expires tomorrow'));
    repository.seed(
      note(
        id: 'low',
        title: 'Milk is running low',
        type: AppNotificationType.lowStock,
        message: 'Only 1 bottle remains.',
        createdAt: clock.subtract(const Duration(minutes: 1)),
      ),
    );
    await pumpBell(tester, repository: repository);
    await openPanel(tester);

    await tester.tap(find.byTooltip('Notification actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Notification deleted.'), findsOneWidget);
    expect(repository.activeOf('alice'), hasLength(1));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('cancel and dismiss leave delete all unchanged', (tester) async {
    final repository = MemoryNotificationRepository();
    repository.seed(note(id: 'soon', title: 'Milk expires tomorrow'));
    await pumpBell(tester, repository: repository);
    await openPanel(tester);

    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all notifications?'), findsOneWidget);
    expect(
      find.text(
        'This will clear all notifications from your notification list.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Milk expires tomorrow'), findsOneWidget);
    expect(repository.activeOf('alice'), hasLength(1));

    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Milk expires tomorrow'), findsOneWidget);
    expect(repository.activeOf('alice'), hasLength(1));
  });

  testWidgets('confirming delete all clears every active notification', (
    tester,
  ) async {
    final repository = MemoryNotificationRepository();
    for (var index = 0; index < 6; index++) {
      repository.seed(
        note(
          id: 'n$index',
          title: 'Alert $index',
          createdAt: clock.subtract(Duration(minutes: index)),
        ),
      );
    }
    await pumpBell(tester, repository: repository);
    await openPanel(tester);

    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    final deleteAll = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Delete All'),
    );
    expect(
      deleteAll.style?.foregroundColor?.resolve({}),
      AppTheme.light.colorScheme.error,
    );

    await tester.tap(find.text('Delete All'));
    await tester.pumpAndSettle();

    expect(repository.activeOf('alice'), isEmpty);
    expect(
      repository.docs['alice']!.values.every(
        (notification) => notification.deletedAt != null,
      ),
      isTrue,
    );
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('No new pantry alerts right now.'), findsOneWidget);
    expect(find.text('All notifications deleted.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
  });

  testWidgets('a failed write restores the unread row', (tester) async {
    final repository = MemoryNotificationRepository()..failWrites = 1;
    repository.seed(note(id: 'soon', title: 'Milk expires tomorrow'));
    await pumpBell(tester, repository: repository);
    await openPanel(tester);

    await tester.tap(find.text('Milk expires tomorrow'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-unread-soon')),
      findsOneWidget,
    );
    expect(repository.docs['alice']!['soon']!.isRead, isFalse);
    expect(
      find.text('Couldn’t update that notification. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('firebase'), findsNothing);
  });

  testWidgets('empty, loading, and error states stay friendly', (tester) async {
    final empty = MemoryNotificationRepository();
    await pumpBell(tester, repository: empty);
    await openPanel(tester);
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
    expect(find.text('Delete all'), findsNothing);
    final markAll = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Mark all as read'),
    );
    expect(markAll.onPressed, isNull);
  });

  testWidgets('loading and error states stay friendly', (tester) async {
    final loading = MemoryNotificationRepository()..pauseWatch = true;
    await pumpBell(tester, repository: loading);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Couldn’t load notifications'), findsNothing);
  });

  testWidgets('error state offers retry without a raw exception', (
    tester,
  ) async {
    final broken = MemoryNotificationRepository()..failWatch = true;
    await pumpBell(tester, repository: broken);
    await openPanel(tester);
    expect(find.text('Couldn’t load notifications'), findsOneWidget);
    expect(find.text('Please try again.'), findsOneWidget);
    expect(find.textContaining('firebase'), findsNothing);

    broken.failWatch = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
  });

  testWidgets('wide screens anchor the panel and phones cover the nav', (
    tester,
  ) async {
    final repository = MemoryNotificationRepository();
    repository.seed(note(id: 'soon', title: 'Milk expires tomorrow'));
    await pumpBell(tester, repository: repository, size: const Size(900, 800));
    await openPanel(tester);

    expect(find.byType(BottomSheet), findsNothing);
    final panel = tester.getRect(
      find.byKey(const ValueKey('notification-panel')),
    );
    expect(panel.left, greaterThan(200));
    expect(panel.right, lessThanOrEqualTo(900));
    expect(find.text('Milk expires tomorrow'), findsOneWidget);

    await tester.tapAt(const Offset(8, 400));
    await tester.pumpAndSettle();

    await pumpBell(
      tester,
      repository: repository,
      navigation: const SizedBox(
        key: ValueKey('home-nav'),
        height: 80,
        child: ColoredBox(color: Colors.white),
      ),
    );
    await openPanel(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    final nav = tester.getRect(find.byKey(const ValueKey('home-nav')));
    expect(sheet.bottom, greaterThan(nav.top));
    expect(find.text('Milk expires tomorrow'), findsOneWidget);
  });

  testWidgets('light and dark panels stay readable at a large text scale', (
    tester,
  ) async {
    final repository = MemoryNotificationRepository();
    repository.seed(
      note(
        id: 'soon',
        title: 'Very long milk name that should stay on two lines',
        message:
            'Use it soon to avoid food waste before it has to be thrown away.',
      ),
    );

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await pumpBell(
        tester,
        repository: repository,
        theme: theme,
        size: const Size(320, 700),
        scale: 1.6,
      );
      await openPanel(tester);
      expect(
        find.text('Very long milk name that should stay on two lines'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('switching users does not show the previous account', (
    tester,
  ) async {
    final repository = MemoryNotificationRepository();
    repository.seed(note(id: 'alice-milk', title: 'Milk expires tomorrow'));
    repository.seed(
      note(
        id: 'bob-rice',
        userId: 'bob',
        title: 'Rice expired yesterday',
        type: AppNotificationType.expired,
        message: 'Check whether it should be recorded as waste.',
      ),
    );
    final uids = await pumpBell(tester, repository: repository);
    await openPanel(tester);
    expect(find.text('Milk expires tomorrow'), findsOneWidget);
    expect(find.text('Rice expired yesterday'), findsNothing);

    uids.add('bob');
    await tester.pumpAndSettle();
    expect(find.text('Rice expired yesterday'), findsOneWidget);
    expect(find.text('Milk expires tomorrow'), findsNothing);

    uids.add(null);
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('Rice expired yesterday'), findsNothing);
    expect(
      find.byKey(const ValueKey('notification-unread-badge')),
      findsNothing,
    );
  });
}
