import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/local_notification_service.dart';
import '../services/expiry_notification_service.dart';

final expiryNotificationServiceProvider = Provider((ref) {
  return ExpiryNotificationService(ref.watch(localNotificationsPluginProvider));
});
