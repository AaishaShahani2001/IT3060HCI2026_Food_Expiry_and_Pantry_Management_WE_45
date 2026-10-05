import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_expiry_and_pantry_management/core/notifications/local_notification_service.dart';
import 'package:food_expiry_and_pantry_management/core/providers/theme_mode_provider.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/services/expiry_notification_provider.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/services/expiry_notification_service.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_notification_settings_provider.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/models/app_notification.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/presentation/providers/notification_providers.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/presentation/widgets/notification_popup_host.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';

import 'memory_notification_repository.dart';

class RecordingExpiryNotifications extends ExpiryNotificationService {
  RecordingExpiryNotifications() : super(FlutterLocalNotificationsPlugin());

  final List<String> titles = [];

  @override
  Future<void> showExpiryNotification({
    required String title,
    required String body,
  }) async {
    titles.add(title);
  }
}

void main() {
  final popup = find.byKey(const ValueKey('expiry-notification-popup'));
  late MemoryNotificationRepository repository;
  late RecordingExpiryNotifications service;
  late SharedPreferences prefs;
  late StreamController<String?> users;
  late ProviderContainer container;
  late DateTime now;
  var views = 0;

  AppNotification note(
    String id, {
    String uid = 'alice',
    AppNotificationType type = AppNotificationType.expiringSoon,
    bool read = false,
    bool deleted = false,
    DateTime? expiry,
  }) => AppNotification(
    id: id,
    userId: uid,
    type: type,
    title: '$id expiry alert',
    message: 'Use it soon to avoid food waste.',
    alertKey: id,
    isRead: read,
    createdAt: DateTime(2026, 10, 5),
    expiryDate:
        expiry ??
        DateTime(2026, 10, type == AppNotificationType.expired ? 4 : 6),
    deletedAt: deleted ? DateTime(2026, 10, 5) : null,
  );

  setUp(() async {
    repository = MemoryNotificationRepository();
    service = RecordingExpiryNotifications();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    users = StreamController<String?>.broadcast();
    views = 0;
    now = DateTime(2026, 10, 5, 12);
  });

  tearDown(() async => users.close());

  Future<void> pumpHost(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
          notificationUserIdProvider.overrideWith((ref) => users.stream),
          expiryNotificationServiceProvider.overrideWithValue(service),
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: NotificationPopupHost(child: child!, onView: () => views++),
          ),
          home: const Scaffold(body: Text('Pantry screen without a bell')),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationPopupHost)),
    );
    users.add('alice');
    await tester.pumpAndSettle();
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets(
    'adding grains expiring tomorrow pops up with one-day-before settings',
    (tester) async {
      await prefs.setInt('expiry_notif_days_before', 1);
      await pumpHost(tester);
      await container
          .read(notificationSyncProvider)
          .synchronize(
            userId: 'alice',
            items: [
              PantryItem(
                id: 'grains',
                name: 'grains',
                category: PantryCategory.grains,
                location: PantryLocation.pantry,
                quantity: 10,
                unit: PantryUnit.kg,
                expiryDate: DateTime(2026, 10, 6),
              ),
            ],
          );
      await tester.pumpAndSettle();
      expect(find.text('grains expires tomorrow'), findsOneWidget);
      expect(popup, findsOneWidget);
      expect(service.titles, ['grains expires tomorrow']);
    },
  );

  testWidgets(
    'waits for the selected days-before window without consuming the alert',
    (tester) async {
      await prefs.setInt('expiry_notif_days_before', 1);
      repository.seed(note('grains', expiry: DateTime(2026, 10, 7)));
      await pumpHost(tester);
      expect(popup, findsNothing);
      now = DateTime(2026, 10, 6, 9);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget);
      expect(service.titles, ['grains expiry alert']);
    },
  );

  testWidgets(
    'retries an unread alert after expiry notifications are enabled',
    (tester) async {
      await prefs.setBool('expiry_notif_enabled', false);
      await pumpHost(tester);
      repository.seed(note('grains'));
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      final settings = container.read(expiryNotificationSettingsProvider);
      await container
          .read(expiryNotificationSettingsProvider.notifier)
          .saveSettings(
            settings.copyWith(notificationsEnabled: true, daysBefore: 1),
          );
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget);
      expect(service.titles, ['grains expiry alert']);
    },
  );

  testWidgets(
    'does not discard an unread alert stored as seen by the previous implementation',
    (tester) async {
      await prefs.setStringList('expiry_popup_seen_alice', ['grains']);
      repository.seed(note('grains'));
      await pumpHost(tester);
      expect(popup, findsOneWidget);
      expect(service.titles, ['grains expiry alert']);
    },
  );

  testWidgets(
    'automatically shows expiry alerts without a bell and opens expiry',
    (tester) async {
      await pumpHost(tester);
      repository.seed(note('Milk'));
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget);
      expect(find.text('Milk expiry alert'), findsOneWidget);
      expect(service.titles, ['Milk expiry alert']);
      expect(container.read(unreadNotificationCountProvider), 1);
      await tester.tap(find.text('View expiry items'));
      await tester.pumpAndSettle();
      expect(views, 1);
      expect(popup, findsNothing);
      expect(container.read(unreadNotificationCountProvider), 1);
    },
  );

  testWidgets(
    'groups initial alerts and does not repeat after updates or remount',
    (tester) async {
      repository.seed(note('Milk'));
      repository.seed(note('Bread', type: AppNotificationType.expired));
      await pumpHost(tester);
      expect(find.text('2 pantry expiry alerts'), findsOneWidget);
      expect(service.titles, ['2 pantry expiry alerts']);
      await tester.tap(find.byKey(const ValueKey('dismiss-expiry-alert')));
      await tester.pumpAndSettle();
      await repository.markAsRead('alice', 'Milk');
      await repository.markAsUnread('alice', 'Milk');
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpHost(tester);
      expect(popup, findsNothing);
      expect(service.titles, hasLength(1));
    },
  );

  testWidgets(
    'respects notification switches and skips low stock, read and deleted alerts',
    (tester) async {
      await prefs.setBool('expiry_notif_expiring_soon', false);
      await pumpHost(tester);
      repository.seed(note('Soon'));
      repository.seed(note('Stock', type: AppNotificationType.lowStock));
      repository.seed(note('Read', read: true));
      repository.seed(note('Deleted', deleted: true));
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      expect(service.titles, isEmpty);
      repository.seed(note('Expired', type: AppNotificationType.expired));
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget);
      final settings = container.read(expiryNotificationSettingsProvider);
      await container
          .read(expiryNotificationSettingsProvider.notifier)
          .saveSettings(settings.copyWith(notificationsEnabled: false));
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      repository.seed(
        note('Another expired', type: AppNotificationType.expired),
      );
      await tester.pumpAndSettle();
      expect(service.titles, ['Expired expiry alert']);
    },
  );

  testWidgets(
    'clears the popup on sign-out and isolates seen alerts per user',
    (tester) async {
      repository.seed(note('Milk'));
      await pumpHost(tester);
      expect(popup, findsOneWidget);
      users.add(null);
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      repository.seed(note('Milk', uid: 'bob'));
      users.add('bob');
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget);
      expect(service.titles, hasLength(2));
    },
  );

  testWidgets(
    'popup fits narrow screens with large text and dismisses automatically',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.seed(note('Milk'));
      await pumpHost(tester, scale: 2);
      expect(popup, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 9));
      expect(popup, findsNothing);
    },
  );

  test('expiry notification payload routes to expiry', () {
    expect(
      notificationRouteForPayload(expiryNotificationPayload),
      AppRoutes.expiry,
    );
  });

  test(
    'native alert requests permission, uses heads-up settings and preserves initialization',
    () async {
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'requestNotificationsPermission'
                ? true
                : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final nativeService = ExpiryNotificationService(
        FlutterLocalNotificationsPlugin(),
      );
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      await nativeService.showExpiryNotification(
        title: 'Milk expires tomorrow',
        body: 'Use it soon.',
      );
      expect(calls.map((call) => call.method), [
        'requestNotificationsPermission',
        'show',
      ]);
      final args = calls.last.arguments as Map;
      expect(args['payload'], expiryNotificationPayload);
      final android = args['platformSpecifics'] as Map;
      expect(android['importance'], Importance.max.value);
      expect(android['priority'], Priority.high.value);
      expect(android['playSound'], true);
    },
  );
}
