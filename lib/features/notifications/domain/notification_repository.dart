import 'models/app_notification.dart';
import 'notification_planner.dart';

/// Persistence for the in-app notification center.
///
/// Widgets talk to the Riverpod controller, which talks to this repository.
abstract class NotificationRepository {
  Stream<List<AppNotification>> watchActive(String userId, {int limit = 50});

  /// Every active notification for [userId], newest first.
  ///
  /// Unlike [watchActive], this stream is not capped, so the full list screen
  /// is not limited to the preview's five rows.
  Stream<List<AppNotification>> watchAll(String userId);

  Future<Set<String>> fetchAlertKeys(String userId);

  Future<StockMemory> fetchStockMemory(String userId);

  Future<void> saveStockMemory(String userId, StockMemory memory);

  Future<void> createIfAbsent(AppNotification notification);

  Future<void> markAsRead(String userId, String notificationId);

  Future<void> markAsUnread(String userId, String notificationId);

  Future<void> markAllAsRead(String userId);

  Future<void> deleteNotification(String userId, String notificationId);

  Future<void> deleteAllNotifications(String userId);
}

/// Thrown when a notification write cannot be saved.
///
/// The message is safe to ignore in the UI; screens use their own copy.
class NotificationFailure implements Exception {
  const NotificationFailure();
}
