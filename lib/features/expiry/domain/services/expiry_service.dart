import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/domain/utils/expiry_status.dart';

/// Provides expiry-related calculations and filtering for pantry items.
///
/// This service does not access Firebase or modify pantry data.
/// It only analyzes the existing [PantryItem] objects.
class ExpiryService {
  const ExpiryService();

  /// Returns the number of calendar days until an item expires.
  ///
  /// Examples:
  /// - 2  -> expires in 2 days
  /// - 0  -> expires today
  /// - -1 -> expired yesterday
  ///
  /// Returns null when the item has no expiry date.
  int? daysUntilExpiry(
    PantryItem item, {
    DateTime? referenceDate,
  }) {
    final expiryDate = item.expiryDate;
    if (expiryDate == null) return null;

    final reference = referenceDate ?? DateTime.now();

    final today = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );

    final expiry = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    return expiry.difference(today).inDays;
  }

  /// Returns the number of days an item is overdue.
  ///
  /// Returns:
  /// - 0 when the item is not overdue
  /// - positive number when the item has expired
  int daysOverdue(
    PantryItem item, {
    DateTime? referenceDate,
  }) {
    final days = daysUntilExpiry(
      item,
      referenceDate: referenceDate,
    );

    if (days == null || days >= 0) {
      return 0;
    }

    return days.abs();
  }

  /// Returns all items that have already expired.
  List<PantryItem> expiredItems(
    Iterable<PantryItem> items, {
    DateTime? referenceDate,
  }) {
    return items
        .where(
          (item) =>
              daysUntilExpiry(
                item,
                referenceDate: referenceDate,
              ) !=
              null &&
              daysUntilExpiry(
                    item,
                    referenceDate: referenceDate,
                  )! <
                  0,
        )
        .toList();
  }

  /// Returns items that expire today or within [days].
  ///
  /// By default this follows the existing project rule:
  /// 0–3 days = "Expiring soon".
  List<PantryItem> expiringSoonItems(
    Iterable<PantryItem> items, {
    int days = kExpiryExpiringSoonDays,
    DateTime? referenceDate,
  }) {
    return items
        .where(
          (item) {
            final remaining = daysUntilExpiry(
              item,
              referenceDate: referenceDate,
            );

            return remaining != null &&
                remaining >= 0 &&
                remaining <= days;
          },
        )
        .toList();
  }

  /// Returns items with a valid expiry date that are not expiring soon.
  List<PantryItem> freshItems(
    Iterable<PantryItem> items, {
    DateTime? referenceDate,
  }) {
    return items
        .where(
          (item) {
            final remaining = daysUntilExpiry(
              item,
              referenceDate: referenceDate,
            );

            return remaining != null && remaining > kExpiryExpiringSoonDays;
          },
        )
        .toList();
  }

  /// Returns items that do not have an expiry date.
  List<PantryItem> itemsWithoutExpiry(
    Iterable<PantryItem> items,
  ) {
    return items.where((item) => item.expiryDate == null).toList();
  }

  /// Returns all items that require attention.
  ///
  /// This includes:
  /// - expired items
  /// - items expiring today
  /// - items expiring within the configured expiry window
  List<PantryItem> attentionItems(
    Iterable<PantryItem> items, {
    DateTime? referenceDate,
  }) {
    return [
      ...expiredItems(
        items,
        referenceDate: referenceDate,
      ),
      ...expiringSoonItems(
        items,
        referenceDate: referenceDate,
      ),
    ];
  }

  /// Sorts pantry items by expiry urgency.
  ///
  /// Expired items appear first, followed by products
  /// with the nearest upcoming expiry.
  ///
  /// Items without an expiry date are placed last.
  List<PantryItem> sortByExpiryUrgency(
    Iterable<PantryItem> items, {
    DateTime? referenceDate,
  }) {
    final sorted = List<PantryItem>.from(items);

    sorted.sort((a, b) {
      final aDays = daysUntilExpiry(
        a,
        referenceDate: referenceDate,
      );

      final bDays = daysUntilExpiry(
        b,
        referenceDate: referenceDate,
      );

      // Items without an expiry date go to the end.
      if (aDays == null && bDays == null) return 0;
      if (aDays == null) return 1;
      if (bDays == null) return -1;

      return aDays.compareTo(bDays);
    });

    return sorted;
  }

  /// Returns a human-readable description of the expiry timing.
  String expiryMessage(
    PantryItem item, {
    DateTime? referenceDate,
  }) {
    final days = daysUntilExpiry(
      item,
      referenceDate: referenceDate,
    );

    if (days == null) {
      return 'Expiry date unknown';
    }

    if (days < 0) {
      final overdue = days.abs();

      if (overdue == 1) {
        return 'Expired 1 day ago';
      }

      return 'Expired $overdue days ago';
    }

    if (days == 0) {
      return 'Expires today';
    }

    if (days == 1) {
      return 'Expires tomorrow';
    }

    return 'Expires in $days days';
  }

  /// Determines the smart-alert priority for an item.
  ///
  /// Priority is based primarily on expiry urgency and secondarily
  /// on whether the item has stock available.
  String alertPriority(
    PantryItem item, {
    DateTime? referenceDate,
  }) {
    final days = daysUntilExpiry(
      item,
      referenceDate: referenceDate,
    );

    if (days == null) {
      return 'none';
    }

    if (days < 0) {
      return 'critical';
    }

    if (days <= 1) {
      return 'high';
    }

    if (days <= kExpiryExpiringSoonDays) {
      return 'medium';
    }

    return 'none';
  }

  /// Creates a smart alert message for an item when appropriate.
  ///
  /// Returns null when no alert is required.
  String? smartAlertMessage(
    PantryItem item, {
    DateTime? referenceDate,
  }) {
    final priority = alertPriority(
      item,
      referenceDate: referenceDate,
    );

    switch (priority) {
      case 'critical':
        return '${item.name} has expired. Remove it from active stock.';

      case 'high':
        return '${item.name} expires very soon. Consider prioritizing it for sale.';

      case 'medium':
        return '${item.name} expires within 3 days. Consider using or selling it soon.';

      default:
        return null;
    }
  }

  /// Returns summary counts for the expiry dashboard.
  ({
    int total,
    int expired,
    int expiringSoon,
    int fresh,
    int unknown,
  }) buildSummary(
    Iterable<PantryItem> items, {
    DateTime? referenceDate,
  }) {
    final itemList = List<PantryItem>.from(items);

    return (
      total: itemList.length,
      expired: expiredItems(
        itemList,
        referenceDate: referenceDate,
      ).length,
      expiringSoon: expiringSoonItems(
        itemList,
        referenceDate: referenceDate,
      ).length,
      fresh: freshItems(
        itemList,
        referenceDate: referenceDate,
      ).length,
      unknown: itemsWithoutExpiry(itemList).length,
    );
  }
}