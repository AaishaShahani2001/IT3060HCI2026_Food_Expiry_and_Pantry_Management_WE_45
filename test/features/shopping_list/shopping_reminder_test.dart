import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/notifications/local_notification_service.dart';
import 'package:food_expiry_and_pantry_management/core/providers/theme_mode_provider.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/domain/models/shopping_reminder.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/domain/services/shopping_reminder_notification_service.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_reminder_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/widgets/shopping_reminder_setup_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements ShoppingReminderScheduler {
  final Map<String, ShoppingReminder> active = {};
  final List<({String uid, ShoppingReminder reminder})> scheduled = [];
  final List<String> cancelledUids = [];

  @override
  Future<void> schedule({
    required String uid,
    required ShoppingReminder reminder,
  }) async {
    if (active.containsKey(uid)) cancelledUids.add(uid);
    scheduled.add((uid: uid, reminder: reminder));
    active[uid] = reminder;
  }

  @override
  Future<void> cancelAll({required String uid}) async {
    cancelledUids.add(uid);
    active.remove(uid);
  }
}

void main() {
  late SharedPreferences preferences;
  late _FakeScheduler scheduler;
  var now = DateTime(2026, 10, 1, 10);

  ShoppingReminder reminder(List<DateTime> times) => ShoppingReminder(
    date: DateTime(times.first.year, times.first.month, times.first.day),
    times: times,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    scheduler = _FakeScheduler();
    now = DateTime(2026, 10, 1, 10);
  });

  ProviderContainer createContainer(String uid) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        shoppingAuthUidProvider.overrideWith((ref) => Stream.value(uid)),
        shoppingReminderSchedulerProvider.overrideWithValue(scheduler),
        shoppingReminderClockProvider.overrideWithValue(() => now),
      ],
    );
    container.listen(shoppingReminderProvider, (_, _) {});
    return container;
  }

  Future<void> openReminderSheet(
    WidgetTester tester, {
    required ValueChanged<ShoppingReminder> onSaved,
    ShoppingReminder? initialReminder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final selected = await showModalBottomSheet<ShoppingReminder>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => ShoppingReminderSetupSheet(
                      clock: () => now,
                      initialReminder: initialReminder,
                    ),
                  );
                  if (selected != null) onSaved(selected);
                },
                child: const Text('Open reminder'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reminder'));
    await tester.pumpAndSettle();
  }

  Future<void> editReminderTime(
    WidgetTester tester,
    int index, {
    required int hour,
    required int minute,
  }) async {
    await tester.tap(find.byKey(ValueKey('shopping-reminder-time-$index')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    final dialog = find.byType(TimePickerDialog);
    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), hour.toString().padLeft(2, '0'));
    await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
    await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
    await tester.pumpAndSettle();
  }

  Future<void> selectReminderDate(
    WidgetTester tester, {
    required int day,
    int monthsForward = 0,
  }) async {
    await tester.tap(find.byKey(const ValueKey('shopping-reminder-date')));
    await tester.pumpAndSettle();
    for (var index = 0; index < monthsForward; index++) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    final dialog = find.byType(DatePickerDialog);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('$day')).last,
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
    await tester.pumpAndSettle();
  }

  test('three Shopping notification slot IDs are stable and unique', () {
    final firstRun = [
      for (var slot = 0; slot < shoppingReminderMaximumCount; slot++)
        shoppingReminderNotificationId('alice', slot),
    ];
    final secondRun = [
      for (var slot = 0; slot < shoppingReminderMaximumCount; slot++)
        shoppingReminderNotificationId('alice', slot),
    ];
    expect(firstRun, secondRun);
    expect(firstRun.toSet().length, 3);
    expect(shoppingReminderNotificationId('bob', 0), isNot(firstRun.first));
    expect(firstRun, everyElement(inInclusiveRange(0, 0x7fffffff)));
    expect(
      firstRun.map((id) => id & 0xff000000),
      everyElement(shoppingReminderNotificationIdNamespace),
    );
    expect(() => shoppingReminderNotificationId('alice', 3), throwsRangeError);
  });

  test('shopping payload maps only to the existing Shopping route', () {
    expect(
      notificationRouteForPayload(shoppingReminderPayload),
      AppRoutes.shopping,
    );
    expect(notificationRouteForPayload('expiry-notification'), isNull);
    expect(notificationRouteForPayload(null), isNull);
  });

  test('one, two, and three reminders validate; more than three does not', () {
    for (var count = 1; count <= 3; count++) {
      final times = [
        for (var index = 1; index <= count; index++)
          now.add(Duration(hours: index)),
      ];
      expect(shoppingReminderValidationMessage(reminder(times), now), isNull);
    }
    final four = reminder([
      for (var index = 1; index <= 4; index++) now.add(Duration(hours: index)),
    ]);
    expect(
      shoppingReminderValidationMessage(four, now),
      'Choose between 1 and 3 reminder times.',
    );
  });

  test('past date and today past time are rejected', () {
    final yesterday = reminder([now.subtract(const Duration(days: 1))]);
    expect(
      shoppingReminderValidationMessage(yesterday, now),
      'Choose today or a future date.',
    );
    final earlierToday = reminder([now.subtract(const Duration(hours: 1))]);
    expect(
      shoppingReminderValidationMessage(earlierToday, now),
      'Choose reminder times that are still in the future.',
    );
  });

  test('validation compares complete local date and time values', () {
    now = DateTime(2026, 10, 30, 18);

    expect(
      shoppingReminderValidationMessage(
        reminder([DateTime(2026, 10, 30, 18, 30)]),
        now,
      ),
      isNull,
    );
    expect(
      shoppingReminderValidationMessage(
        reminder([DateTime(2026, 10, 30, 19)]),
        now,
      ),
      isNull,
    );
    expect(
      shoppingReminderValidationMessage(
        reminder([DateTime(2026, 10, 30, 17)]),
        now,
      ),
      'Choose reminder times that are still in the future.',
    );
    expect(
      shoppingReminderValidationMessage(
        reminder([DateTime(2026, 10, 31, 8)]),
        now,
      ),
      isNull,
    );
    expect(
      shoppingReminderValidationMessage(
        reminder([DateTime(2026, 11, 5, 15)]),
        now,
      ),
      isNull,
    );
  });

  test('scheduling conversion preserves the selected local instant', () {
    final selected = DateTime(2026, 11, 5, 15);
    final scheduled = shoppingReminderScheduledTime(selected);

    expect(scheduled.millisecondsSinceEpoch, selected.millisecondsSinceEpoch);
    expect(
      DateTime.fromMillisecondsSinceEpoch(scheduled.millisecondsSinceEpoch),
      selected,
    );
  });

  test('duplicate times are rejected and unique future times are accepted', () {
    final future = now.add(const Duration(hours: 1));
    expect(
      shoppingReminderValidationMessage(reminder([future, future]), now),
      'Choose a different time for each reminder.',
    );
    expect(
      shoppingReminderValidationMessage(
        reminder([future, now.add(const Duration(hours: 2))]),
        now,
      ),
      isNull,
    );
  });

  for (var count = 1; count <= 3; count++) {
    test(
      '$count reminder selection schedules exactly $count one-time slots',
      () async {
        final container = createContainer('alice');
        addTearDown(container.dispose);
        await container.read(shoppingReminderProvider.future);
        final selected = reminder([
          for (var index = 1; index <= count; index++)
            now.add(Duration(hours: index)),
        ]);

        await container
            .read(shoppingReminderProvider.notifier)
            .setReminder(selected);

        expect(scheduler.scheduled.single.reminder.times.length, count);
        expect(scheduler.active['alice']?.times.length, count);
      },
    );
  }

  test(
    'changing a reminder replaces the active group without duplicates',
    () async {
      final container = createContainer('alice');
      addTearDown(container.dispose);
      await container.read(shoppingReminderProvider.future);
      final first = reminder([now.add(const Duration(hours: 1))]);
      final second = reminder([
        now.add(const Duration(days: 1, hours: 2)),
        now.add(const Duration(days: 1, hours: 4)),
      ]);

      await container
          .read(shoppingReminderProvider.notifier)
          .setReminder(first);
      await container
          .read(shoppingReminderProvider.notifier)
          .setReminder(second);

      expect(scheduler.scheduled.length, 2);
      expect(scheduler.active, {'alice': second});
      expect(scheduler.cancelledUids, ['alice']);
      expect(
        container.read(shoppingReminderProvider).requireValue,
        same(second),
      );
    },
  );

  test('reminder date and times restore after provider recreation', () async {
    final selected = reminder([
      now.add(const Duration(days: 2, hours: 1)),
      now.add(const Duration(days: 2, hours: 3)),
      now.add(const Duration(days: 2, hours: 5)),
    ]);
    final first = createContainer('alice');
    await first.read(shoppingReminderProvider.future);
    await first.read(shoppingReminderProvider.notifier).setReminder(selected);
    first.dispose();

    final restored = createContainer('alice');
    addTearDown(restored.dispose);
    final value = await restored.read(shoppingReminderProvider.future);
    expect(value?.date, selected.date);
    expect(value?.times, selected.times);
  });

  test('reminder persistence is isolated by signed-in UID', () async {
    final aliceReminder = reminder([now.add(const Duration(hours: 1))]);
    final bobReminder = reminder([now.add(const Duration(hours: 2))]);
    final alice = createContainer('alice');
    await alice.read(shoppingReminderProvider.future);
    await alice
        .read(shoppingReminderProvider.notifier)
        .setReminder(aliceReminder);
    alice.dispose();

    final bob = createContainer('bob');
    await bob.read(shoppingReminderProvider.future);
    expect(bob.read(shoppingReminderProvider).requireValue, isNull);
    await bob.read(shoppingReminderProvider.notifier).setReminder(bobReminder);
    bob.dispose();

    expect(
      preferences.getString(shoppingReminderStorageKey('alice')),
      isNot(preferences.getString(shoppingReminderStorageKey('bob'))),
    );
  });

  test(
    'fully expired reminder is cleared and all Shopping slots cancel',
    () async {
      final expired = reminder([
        now.subtract(const Duration(hours: 2)),
        now.subtract(const Duration(hours: 1)),
      ]);
      await preferences.setString(
        shoppingReminderStorageKey('alice'),
        jsonEncode(expired.toJson()),
      );
      final container = createContainer('alice');
      addTearDown(container.dispose);

      expect(await container.read(shoppingReminderProvider.future), isNull);
      expect(scheduler.cancelledUids, ['alice']);
      expect(
        preferences.containsKey(shoppingReminderStorageKey('alice')),
        isFalse,
      );
    },
  );

  test('group remains active while at least one reminder is future', () async {
    final partlyCompleted = reminder([
      now.subtract(const Duration(hours: 1)),
      now.add(const Duration(hours: 1)),
    ]);
    await preferences.setString(
      shoppingReminderStorageKey('alice'),
      jsonEncode(partlyCompleted.toJson()),
    );
    final container = createContainer('alice');
    addTearDown(container.dispose);

    final restored = await container.read(shoppingReminderProvider.future);
    expect(restored?.times, partlyCompleted.times);
    expect(scheduler.cancelledUids, isEmpty);
  });

  test('malformed persisted data fails safely and is removed', () async {
    await preferences.setString(shoppingReminderStorageKey('alice'), '{bad');
    final container = createContainer('alice');
    addTearDown(container.dispose);

    expect(await container.read(shoppingReminderProvider.future), isNull);
    expect(scheduler.cancelledUids, ['alice']);
    expect(
      preferences.containsKey(shoppingReminderStorageKey('alice')),
      isFalse,
    );
  });

  test(
    'cancel clears only current UID Shopping state, not Expiry settings',
    () async {
      const expiryPreference = 'expiry_notifications.enabled';
      await preferences.setBool(expiryPreference, true);
      final container = createContainer('alice');
      addTearDown(container.dispose);
      await container.read(shoppingReminderProvider.future);
      await container
          .read(shoppingReminderProvider.notifier)
          .setReminder(reminder([now.add(const Duration(hours: 1))]));

      await container.read(shoppingReminderProvider.notifier).cancelReminder();

      expect(scheduler.cancelledUids, ['alice']);
      expect(scheduler.active, isEmpty);
      expect(container.read(shoppingReminderProvider).requireValue, isNull);
      expect(preferences.getBool(expiryPreference), isTrue);
    },
  );

  test('active reminder date/count and time labels are compact', () {
    final selected = reminder([
      DateTime(2026, 10, 2, 10),
      DateTime(2026, 10, 2, 15),
      DateTime(2026, 10, 2, 18),
    ]);
    expect(shoppingReminderLabel(selected, now), 'Tomorrow • 3 reminders');
    expect(shoppingReminderTimeLabel(selected.times[1]), '3:00 PM');
  });

  testWidgets('setup UI rejects duplicate reminder times', (tester) async {
    final duplicate = reminder([
      now.add(const Duration(hours: 1)),
      now.add(const Duration(hours: 1)),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ShoppingReminderSetupSheet(
            clock: () => now,
            initialReminder: duplicate,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('shopping-reminder-submit')));
    await tester.pump();

    expect(
      find.text('Choose a different time for each reminder.'),
      findsOneWidget,
    );
  });

  testWidgets('setup UI rejects a passed time for today', (tester) async {
    final passed = reminder([now.subtract(const Duration(hours: 1))]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ShoppingReminderSetupSheet(
            clock: () => now,
            initialReminder: passed,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('shopping-reminder-submit')));
    await tester.pump();

    expect(
      find.text('Choose reminder times that are still in the future.'),
      findsOneWidget,
    );
  });

  testWidgets('all three new-reminder time slots are independently editable', (
    tester,
  ) async {
    now = DateTime(2026, 10, 30, 18);
    ShoppingReminder? saved;
    await openReminderSheet(tester, onSaved: (value) => saved = value);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await editReminderTime(tester, 0, hour: 19, minute: 0);
    await editReminderTime(tester, 1, hour: 20, minute: 0);
    await editReminderTime(tester, 2, hour: 21, minute: 0);

    expect(find.text('19:00'), findsWidgets);
    expect(find.text('20:00'), findsWidgets);
    expect(find.text('21:00'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('shopping-reminder-submit')));
    await tester.pumpAndSettle();
    expect(saved?.times, [
      DateTime(2026, 10, 30, 19),
      DateTime(2026, 10, 30, 20),
      DateTime(2026, 10, 30, 21),
    ]);
  });

  testWidgets('change reminder can edit its future date and immutable times', (
    tester,
  ) async {
    now = DateTime(2026, 10, 30, 18);
    final existing = reminder([
      DateTime(2026, 10, 31, 8),
      DateTime(2026, 10, 31, 13),
      DateTime(2026, 10, 31, 18),
    ]);
    ShoppingReminder? saved;
    await openReminderSheet(
      tester,
      initialReminder: existing,
      onSaved: (value) => saved = value,
    );

    expect(find.text('Oct 31, 2026'), findsWidgets);
    await selectReminderDate(tester, day: 5, monthsForward: 1);
    expect(find.text('Nov 5, 2026'), findsWidgets);
    await editReminderTime(tester, 0, hour: 7, minute: 0);
    await editReminderTime(tester, 1, hour: 12, minute: 0);
    await editReminderTime(tester, 2, hour: 20, minute: 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('shopping-reminder-submit')));
    await tester.pumpAndSettle();
    expect(saved?.date, DateTime(2026, 11, 5));
    expect(saved?.times, [
      DateTime(2026, 11, 5, 7),
      DateTime(2026, 11, 5, 12),
      DateTime(2026, 11, 5, 20),
    ]);
  });
}
