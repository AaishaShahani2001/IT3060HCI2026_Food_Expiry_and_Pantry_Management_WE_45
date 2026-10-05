import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/providers/theme_mode_provider.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/expiry_reminder_time.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_notification_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('9:00 AM is 09:00 on the day before expiry', () {
    final scheduled = expiryReminderAt(
      expiry: DateTime(2026, 10, 10, 18, 45),
      reminderDays: 1,
      hour: 9,
      minute: 0,
    );

    expect(scheduled, DateTime(2026, 10, 9, 9, 0));
  });

  test('9:00 PM is 21:00', () {
    final scheduled = expiryReminderAt(
      expiry: DateTime(2026, 10, 10),
      reminderDays: 1,
      hour: 21,
      minute: 0,
    );

    expect(scheduled, DateTime(2026, 10, 9, 21, 0));
  });

  test('12:00 AM is 00:00', () {
    final scheduled = expiryReminderAt(
      expiry: DateTime(2026, 10, 10, 16, 5),
      reminderDays: 1,
      hour: 0,
      minute: 0,
    );

    expect(scheduled, DateTime(2026, 10, 9, 0, 0));
  });

  test('12:00 PM is 12:00', () {
    final scheduled = expiryReminderAt(
      expiry: DateTime(2026, 10, 10),
      reminderDays: 1,
      hour: 12,
      minute: 0,
    );

    expect(scheduled, DateTime(2026, 10, 9, 12, 0));
  });

  test('a UTC expiry uses its local calendar date and the saved clock time', () {
    final expiry = DateTime.utc(2026, 10, 9, 18, 30);
    final local = expiry.toLocal();
    final alertDay = DateTime(
      local.year,
      local.month,
      local.day,
    ).subtract(const Duration(days: 1));

    final scheduled = expiryReminderAt(
      expiry: expiry,
      reminderDays: 1,
      hour: 9,
      minute: 0,
    );

    expect(
      scheduled,
      DateTime(alertDay.year, alertDay.month, alertDay.day, 9, 0),
    );
    expect(scheduled.isUtc, isFalse);
    expect(scheduled.hour, 9);
  });

  test('saved hour and minute survive a new settings provider', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);

    await first
        .read(expiryNotificationSettingsProvider.notifier)
        .saveSettings(
          const ExpiryNotificationSettingsState(
            notificationTime: TimeOfDay(hour: 21, minute: 0),
          ),
        );

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    expect(
      restarted.read(expiryNotificationSettingsProvider).notificationTime,
      const TimeOfDay(hour: 21, minute: 0),
    );
    expect(prefs.getInt('expiry_notif_hour'), 21);
    expect(prefs.getInt('expiry_notif_minute'), 0);
  });

  test('12:00 AM and 12:00 PM stay distinct hours', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      expiryNotificationSettingsProvider.notifier,
    );

    await notifier.saveSettings(
      const ExpiryNotificationSettingsState(
        notificationTime: TimeOfDay(hour: 0, minute: 0),
      ),
    );
    expect(
      container.read(expiryNotificationSettingsProvider).notificationTime.hour,
      0,
    );

    await notifier.saveSettings(
      const ExpiryNotificationSettingsState(
        notificationTime: TimeOfDay(hour: 12, minute: 0),
      ),
    );
    expect(
      container.read(expiryNotificationSettingsProvider).notificationTime.hour,
      12,
    );
  });
}
