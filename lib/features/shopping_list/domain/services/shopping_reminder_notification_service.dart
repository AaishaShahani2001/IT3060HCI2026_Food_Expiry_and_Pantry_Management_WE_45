import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/notifications/local_notification_service.dart';
import '../models/shopping_reminder.dart';

const int shoppingReminderNotificationIdNamespace = 0x51000000;
const int shoppingReminderMaximumCount = 3;

tz.TZDateTime shoppingReminderScheduledTime(DateTime localDateTime) =>
    tz.TZDateTime.from(localDateTime, tz.UTC);

int shoppingReminderNotificationId(String uid, int slotIndex) {
  if (slotIndex < 0 || slotIndex >= shoppingReminderMaximumCount) {
    throw RangeError.range(
      slotIndex,
      0,
      shoppingReminderMaximumCount - 1,
      'slotIndex',
    );
  }
  var hash = 0x811c9dc5;
  for (final codeUnit in uid.codeUnits) {
    hash = ((hash ^ codeUnit) * 0x01000193) & 0x003fffff;
  }
  return shoppingReminderNotificationIdNamespace | (hash << 2) | slotIndex;
}

abstract interface class ShoppingReminderScheduler {
  Future<void> schedule({
    required String uid,
    required ShoppingReminder reminder,
  });

  Future<void> cancelAll({required String uid});
}

class LocalShoppingReminderScheduler implements ShoppingReminderScheduler {
  LocalShoppingReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'shopping_reminders',
      'Shopping Reminders',
      channelDescription: 'Reminders to check your shopping list',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            true;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            true;
      case TargetPlatform.macOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            true;
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return true;
    }
  }

  @override
  Future<void> schedule({
    required String uid,
    required ShoppingReminder reminder,
  }) async {
    if (!await _requestPermission()) {
      throw StateError(
        'Notifications are disabled. Enable them before setting a reminder.',
      );
    }
    await cancelAll(uid: uid);
    try {
      for (var index = 0; index < reminder.times.length; index++) {
        await _plugin.zonedSchedule(
          shoppingReminderNotificationId(uid, index),
          'Shopping Reminder',
          'You still have items to buy.',
          shoppingReminderScheduledTime(reminder.times[index]),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: shoppingReminderPayload,
        );
      }
    } catch (_) {
      await cancelAll(uid: uid);
      rethrow;
    }
  }

  @override
  Future<void> cancelAll({required String uid}) async {
    for (var index = 0; index < shoppingReminderMaximumCount; index++) {
      await _plugin.cancel(shoppingReminderNotificationId(uid, index));
    }
  }
}
