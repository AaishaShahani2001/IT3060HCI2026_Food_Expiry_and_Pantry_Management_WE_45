import '../../expiry/domain/services/expiry_service.dart';
import '../../pantry/domain/models/pantry_item.dart';
import '../../pantry/domain/utils/expiry_status.dart';
import 'models/app_notification.dart';

/// Ids last seen above the low-stock threshold, plus the last issued
/// low-stock event number for each item.
///
/// Stored at `users/{userId}/notificationMeta/stock`. A low-stock notification
/// is created only the first time an item is seen at or below
/// [PantryItem.isLowStock], or when it later crosses back under that threshold
/// after being restocked. Staying low does not create another alert.
class StockMemory {
  const StockMemory({
    this.armedItemIds = const {},
    this.lowStockVersions = const {},
  });

  final Set<String> armedItemIds;
  final Map<String, int> lowStockVersions;

  bool sameAs(StockMemory other) {
    if (armedItemIds.length != other.armedItemIds.length) return false;
    if (!armedItemIds.containsAll(other.armedItemIds)) return false;
    if (lowStockVersions.length != other.lowStockVersions.length) return false;
    for (final entry in lowStockVersions.entries) {
      if (other.lowStockVersions[entry.key] != entry.value) return false;
    }
    return true;
  }
}

class PlannedNotification {
  const PlannedNotification({
    required this.alertKey,
    required this.type,
    required this.title,
    required this.message,
    required this.pantryItemId,
    required this.pantryItemName,
    this.expiryDate,
  });

  final String alertKey;
  final AppNotificationType type;
  final String title;
  final String message;
  final String pantryItemId;
  final String pantryItemName;
  final DateTime? expiryDate;

  AppNotification toNotification({
    required String userId,
    required DateTime createdAt,
  }) {
    return AppNotification(
      id: alertKey,
      userId: userId,
      type: type,
      title: title,
      message: message,
      pantryItemId: pantryItemId,
      pantryItemName: pantryItemName,
      expiryDate: expiryDate,
      alertKey: alertKey,
      isRead: false,
      createdAt: createdAt,
    );
  }
}

class NotificationPlan {
  const NotificationPlan({required this.create, required this.memory});

  final List<PlannedNotification> create;
  final StockMemory memory;
}

/// Newest active notifications, without changing [notifications].
List<AppNotification> latestActiveNotifications(
  List<AppNotification> notifications, {
  int limit = 5,
}) {
  final active = [
    for (final notification in notifications)
      if (notification.deletedAt == null) notification,
  ];
  active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (active.length <= limit) {
    return List<AppNotification>.unmodifiable(active);
  }
  return List<AppNotification>.unmodifiable(active.take(limit));
}

String pantryAlertItemId(PantryItem item) {
  final id = (item.firestoreId ?? item.id).trim();
  return id;
}

/// Builds the alerts that should exist for the current pantry snapshot.
///
/// Status comes from [ExpiryStatusHelper] and [ExpiryService]. Low stock uses
/// [PantryItem.isLowStock]. Existing [existingKeys] — including soft-deleted
/// documents — block the same event from being created again.
NotificationPlan planPantryNotifications({
  required List<PantryItem> items,
  required Set<String> existingKeys,
  required StockMemory memory,
  required DateTime now,
  required ExpiryService expiryService,
  int expiringSoonDays = kExpiryExpiringSoonDays,
}) {
  final create = <PlannedNotification>[];
  final reserved = <String>{...existingKeys};
  final nextArmed = <String>{};
  final nextVersions = Map<String, int>.from(memory.lowStockVersions);

  for (final item in items) {
    final itemId = pantryAlertItemId(item);
    if (itemId.isEmpty) continue;
    final name = item.name.trim().isEmpty ? 'Item' : item.name.trim();

    final status = ExpiryStatusHelper.fromDate(
      item.expiryDate,
      referenceDate: now,
      expiringSoonDays: expiringSoonDays,
    );
    final days = expiryService.daysUntilExpiry(item, referenceDate: now);
    if (item.expiryDate != null && days != null) {
      if (status == ExpiryStatus.expiringSoon) {
        _addExpiry(
          create: create,
          reserved: reserved,
          type: AppNotificationType.expiringSoon,
          itemId: itemId,
          name: name,
          expiry: item.expiryDate!,
          title: _expiringTitle(name, days),
          message: days <= 1
              ? 'Use it soon to avoid food waste.'
              : 'Plan to use it soon.',
        );
      } else if (status == ExpiryStatus.expired) {
        final overdue = expiryService.daysOverdue(item, referenceDate: now);
        _addExpiry(
          create: create,
          reserved: reserved,
          type: AppNotificationType.expired,
          itemId: itemId,
          name: name,
          expiry: item.expiryDate!,
          title: overdue == 1 ? '$name expired yesterday' : '$name has expired',
          message: overdue == 1
              ? 'Check whether it should be recorded as waste.'
              : 'Review the item and record it appropriately.',
        );
      }
    }

    if (!item.isLowStock) {
      nextArmed.add(itemId);
      continue;
    }

    final wasArmed = memory.armedItemIds.contains(itemId);
    final prefix = 'lowStock_${itemId}_';
    final hasHistory = existingKeys.any((key) => key.startsWith(prefix));
    if (!wasArmed && hasHistory) continue;

    final version = (nextVersions[itemId] ?? 0) + 1;
    final key = '$prefix$version';
    if (!reserved.add(key)) continue;
    nextVersions[itemId] = version;
    create.add(
      PlannedNotification(
        alertKey: key,
        type: AppNotificationType.lowStock,
        title: '$name is running low',
        message: 'Only ${item.quantityLabel} remains.',
        pantryItemId: itemId,
        pantryItemName: name,
      ),
    );
  }

  return NotificationPlan(
    create: List<PlannedNotification>.unmodifiable(create),
    memory: StockMemory(
      armedItemIds: Set<String>.unmodifiable(nextArmed),
      lowStockVersions: Map<String, int>.unmodifiable(nextVersions),
    ),
  );
}

void _addExpiry({
  required List<PlannedNotification> create,
  required Set<String> reserved,
  required AppNotificationType type,
  required String itemId,
  required String name,
  required DateTime expiry,
  required String title,
  required String message,
}) {
  final timeStamp = expiry.hour == 0 &&
          expiry.minute == 0 &&
          expiry.second == 0 &&
          expiry.millisecond == 0 &&
          expiry.microsecond == 0
      ? ''
      : '_${expiry.hour.toString().padLeft(2, '0')}${expiry.minute.toString().padLeft(2, '0')}';
  final key = '${type.name}_${itemId}_${_dayStamp(expiry)}$timeStamp';
  if (!reserved.add(key)) return;
  create.add(
    PlannedNotification(
      alertKey: key,
      type: type,
      title: title,
      message: message,
      pantryItemId: itemId,
      pantryItemName: name,
      expiryDate: expiry,
    ),
  );
}

String _expiringTitle(String name, int days) {
  if (days <= 0) return '$name expires today';
  if (days == 1) return '$name expires tomorrow';
  return '$name expires in $days days';
}

String _dayStamp(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final year = day.year.toString().padLeft(4, '0');
  final month = day.month.toString().padLeft(2, '0');
  final dayText = day.day.toString().padLeft(2, '0');
  return '$year-$month-$dayText';
}
