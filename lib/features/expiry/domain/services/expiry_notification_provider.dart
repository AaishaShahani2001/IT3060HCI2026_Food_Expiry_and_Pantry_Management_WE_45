import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/expiry_notification_service.dart';

final expiryNotificationServiceProvider = Provider((ref) {
  return ExpiryNotificationService(FlutterLocalNotificationsPlugin());
});
