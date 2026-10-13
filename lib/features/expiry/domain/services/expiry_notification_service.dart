import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/browser_notification_service.dart';

class ExpiryNotificationService {
  final FlutterLocalNotificationsPlugin plugin;
  bool _initialized = false;
  final BrowserNotificationApi? browserNotifications;
  final void Function()? onNotificationTap;

  ExpiryNotificationService(
    this.plugin, {
    this.browserNotifications,
    this.onNotificationTap,
  });

  Future<void> init() async {
    if (_initialized || !supportsLocalNotifications) return;

    try {
      // main() initializes the shared plugin with its navigation callback.
      // Reinitializing here would replace that callback.
      final androidPlugin = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> showExpiryNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      await browserNotifications?.show(
        title: title,
        body: body,
        tag: expiryNotificationPayload,
        onClick: onNotificationTap,
      );
      return;
    }
    if (!supportsLocalNotifications) return;
    if (!_initialized) {
      await init();
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'expiry_popup_channel',
        'Expiry Alerts',
        channelDescription: 'Food expiry reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      final id = DateTime.now().millisecondsSinceEpoch % 100000;
      await plugin.show(
        id,
        title,
        body,
        details,
        payload: expiryNotificationPayload,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }
}
