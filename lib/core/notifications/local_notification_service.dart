import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_routes.dart';

const String shoppingReminderPayload = 'shopping-list-reminder';

String? notificationRouteForPayload(String? payload) =>
    payload == shoppingReminderPayload ? AppRoutes.shopping : null;

final FlutterLocalNotificationsPlugin localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final localNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>(
      (ref) => localNotificationsPlugin,
    );

Future<String?> initializeLocalNotifications({
  required void Function(String? payload) onNotificationResponse,
}) async {
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
