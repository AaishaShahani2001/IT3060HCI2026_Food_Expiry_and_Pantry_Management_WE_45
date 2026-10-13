import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_routes.dart';

const String shoppingReminderPayload = 'shopping-list-reminder';
const String expiryNotificationPayload = 'pantry-expiry-alert';

String? notificationRouteForPayload(String? payload) => switch (payload) {
  shoppingReminderPayload => AppRoutes.shopping,
  expiryNotificationPayload => AppRoutes.expiry,
  _ => null,
};

bool get supportsLocalNotifications =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

final FlutterLocalNotificationsPlugin localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final localNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>(
      (ref) => localNotificationsPlugin,
    );

Future<String?> initializeLocalNotifications({
  required void Function(String? payload) onNotificationResponse,
}) async {
  if (!supportsLocalNotifications) return null;
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
    macOS: DarwinInitializationSettings(),
  );
  await localNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (response) {
      onNotificationResponse(response.payload);
    },
  );
  final launch = await localNotificationsPlugin
      .getNotificationAppLaunchDetails();
  return launch?.didNotificationLaunchApp == true
      ? launch?.notificationResponse?.payload
      : null;
}
