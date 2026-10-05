import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/browser_notification_service.dart';
import '../../../../core/router/app_router.dart';
import '../services/expiry_notification_service.dart';

final expiryNotificationServiceProvider = Provider((ref) {
  return ExpiryNotificationService(
    ref.watch(localNotificationsPluginProvider),
    browserNotifications: ref.watch(browserNotificationServiceProvider),
    onNotificationTap: () => appRouter.go(AppRoutes.expiry),
  );
});
