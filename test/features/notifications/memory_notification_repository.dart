import 'dart:async';

import 'package:food_expiry_and_pantry_management/features/notifications/domain/models/app_notification.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_planner.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/notification_repository.dart';

/// In-memory stand-in for the Firestore notification repository.
class MemoryNotificationRepository implements NotificationRepository {
  final Map<String, Map<String, AppNotification>> docs = {};
  final Map<String, StockMemory> memory = {};
  final Map<String, List<StreamController<List<AppNotification>>>> _listeners =
      {};

  int failWrites = 0;
  bool failWatch = false;
  bool pauseWatch = false;
  Object watchError = Exception('firebase boom');

  List<AppNotification> activeOf(String userId) {
    final stored = docs[userId];
    if (stored == null) return const [];
    final values = stored.values
        .where((notification) => notification.deletedAt == null)
        .toList();
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  void seed(AppNotification notification) {
    docs.putIfAbsent(notification.userId, () => {})[notification.id] =
        notification;
    _emit(notification.userId);
  }

  @override
  Stream<List<AppNotification>> watchActive(String userId, {int limit = 50}) {
    if (failWatch) return Stream.error(watchError);
    late StreamController<List<AppNotification>> controller;
    controller = StreamController<List<AppNotification>>(
      onListen: () {
        if (pauseWatch) return;
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(activeOf(userId).take(limit).toList());
          }
        });
      },
      onCancel: () {
        _listeners[userId]?.remove(controller);
        if (!controller.isClosed) controller.close();
      },
    );
    _listeners.putIfAbsent(userId, () => []).add(controller);
    return controller.stream;
  }

  @override
  Future<Set<String>> fetchAlertKeys(String userId) async {
    return {...?docs[userId]?.keys};
  }

  @override
  Future<StockMemory> fetchStockMemory(String userId) async {
    return memory[userId] ?? const StockMemory();
  }

  @override
  Future<void> saveStockMemory(String userId, StockMemory value) async {
    _guardWrite();
    memory[userId] = value;
  }

  @override
  Future<void> createIfAbsent(AppNotification notification) async {
    _guardWrite();
    final userDocs = docs.putIfAbsent(notification.userId, () => {});
    if (userDocs.containsKey(notification.alertKey)) return;
    userDocs[notification.alertKey] = notification;
    _emit(notification.userId);
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    _guardWrite();
    _replace(
      userId,
      notificationId,
      (notification) =>
          notification.copyWith(isRead: true, readAt: DateTime.now()),
    );
  }

  @override
  Future<void> markAsUnread(String userId, String notificationId) async {
    _guardWrite();
    _replace(
      userId,
      notificationId,
      (notification) => notification.copyWith(isRead: false, clearReadAt: true),
    );
  }

  @override
  Future<void> deleteNotification(String userId, String notificationId) async {
    _guardWrite();
    _replace(
      userId,
      notificationId,
      (notification) => notification.copyWith(deletedAt: DateTime.now()),
    );
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    _guardWrite();
    final userDocs = docs[userId];
    if (userDocs == null) return;
    for (final entry in userDocs.entries.toList()) {
      if (entry.value.deletedAt != null || entry.value.isRead) continue;
      userDocs[entry.key] = entry.value.copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
    }
    _emit(userId);
  }

  @override
  Future<void> deleteAllNotifications(String userId) async {
    _guardWrite();
    final userDocs = docs[userId];
    if (userDocs == null) return;
    final deletedAt = DateTime.now();
    for (final entry in userDocs.entries.toList()) {
      if (entry.value.deletedAt != null) continue;
      userDocs[entry.key] = entry.value.copyWith(deletedAt: deletedAt);
    }
    _emit(userId);
  }

  void _replace(
    String userId,
    String notificationId,
    AppNotification Function(AppNotification notification) update,
  ) {
    final current = docs[userId]?[notificationId];
    if (current == null) throw const NotificationFailure();
    docs[userId]![notificationId] = update(current);
    _emit(userId);
  }

  void _guardWrite() {
    if (failWrites <= 0) return;
    failWrites -= 1;
    throw const NotificationFailure();
  }

  void _emit(String userId) {
    final items = activeOf(userId);
    for (final controller in [...?_listeners[userId]]) {
      if (!controller.isClosed) controller.add(items.take(50).toList());
    }
  }
}
