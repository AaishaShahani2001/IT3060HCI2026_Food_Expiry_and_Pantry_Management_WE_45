import 'dart:developer';

import '../../expiry/domain/services/expiry_service.dart';
import '../../pantry/domain/models/pantry_item.dart';
import 'notification_planner.dart';
import 'notification_repository.dart';

/// Creates pantry and expiry alerts while the app is open and Firestore
/// data is synchronizing.
///
/// This does not run while the app is closed. There is no push notification,
/// background task, or scheduled job behind it.
class NotificationSynchronizer {
  NotificationSynchronizer({
    required this.repository,
    required this.expiryService,
    this.clock,
    this.expiringSoonDays,
  });

  final NotificationRepository repository;
  final ExpiryService expiryService;
  final DateTime Function()? clock;
  final int Function()? expiringSoonDays;

  String? _userId;
  String? _signature;
  Set<String>? _keys;
  StockMemory? _memory;
  bool _running = false;
  bool _again = false;
  String? _queuedUser;
  List<PantryItem>? _queuedItems;

  Future<void> synchronize({
    required String userId,
    required List<PantryItem> items,
  }) async {
    _queuedUser = userId;
    _queuedItems = List<PantryItem>.unmodifiable(items);
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        final user = _queuedUser;
        final snapshot = _queuedItems;
        if (user == null || snapshot == null) return;
        await _syncOnce(user, snapshot);
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _syncOnce(String userId, List<PantryItem> items) async {
    if (_userId != userId) {
      _userId = userId;
      _signature = null;
      _keys = null;
      _memory = null;
    }

    final now = (clock ?? DateTime.now)();
    final daysBefore = expiringSoonDays?.call() ?? 3;
    final signature =
        '${now.year}-${now.month}-${now.day}|$daysBefore\n${_itemSignature(items)}';
    if (signature == _signature && _keys != null && _memory != null) return;

    final keys = _keys ?? await repository.fetchAlertKeys(userId);
    final memory = _memory ?? await repository.fetchStockMemory(userId);
    _keys = keys;
    _memory = memory;

    final plan = planPantryNotifications(
      items: items,
      existingKeys: keys,
      memory: memory,
      now: now,
      expiryService: expiryService,
      expiringSoonDays: daysBefore,
    );

    for (final planned in plan.create) {
      final notification = planned.toNotification(
        userId: userId,
        createdAt: now,
      );
      if (!keys.add(notification.alertKey)) continue;
      try {
        await repository.createIfAbsent(notification);
      } catch (error, stack) {
        keys.remove(notification.alertKey);
        log(
          'Could not save pantry notification',
          error: error,
          stackTrace: stack,
          name: 'notifications',
        );
        rethrow;
      }
    }

    if (!memory.sameAs(plan.memory)) {
      await repository.saveStockMemory(userId, plan.memory);
    }
    _memory = plan.memory;
    _signature = signature;
  }
}

String _itemSignature(List<PantryItem> items) {
  final parts = [
    for (final item in items)
      '${pantryAlertItemId(item)}|${item.name}|${item.expiryDate?.millisecondsSinceEpoch ?? ''}|${item.quantity}|${item.unit.name}',
  ]..sort();
  return parts.join('\n');
}
