import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  void handleNotificationPayload(String? payload) {
    final route = notificationRouteForPayload(payload);
    if (route != null) appRouter.go(route);
  }

  final initialNotificationPayload = await initializeLocalNotifications(
    onNotificationResponse: handleNotificationPayload,
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FreshTrackApp(),
    ),
  );
  if (initialNotificationPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleNotificationPayload(initialNotificationPayload);
    });
  }
}
