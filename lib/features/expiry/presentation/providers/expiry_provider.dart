import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/domain/utils/expiry_status.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';

import '../../data/repositories/firestore_expiry_repository.dart';

import '../../domain/repositories/expiry_repository.dart';
import '../../domain/services/expiry_alert_service.dart';
import '../../domain/services/expiry_notification_provider.dart';
import '../../domain/services/expiry_service.dart';


// ============================================================
// EXPIRY SERVICE
// ============================================================

final expiryServiceProvider = Provider<ExpiryService>((ref) {
  return const ExpiryService();
});


// ============================================================
// FIRESTORE REPOSITORY
// ============================================================

final expiryRepositoryProvider =
    Provider<ExpiryRepository>((ref) {
  return FirestoreExpiryRepository();
});


// ============================================================
// SMART ALERT SERVICE
// ============================================================

final expiryAlertServiceProvider =
    Provider<ExpiryAlertService>((ref) {
  return ExpiryAlertService(
    expiryService: ref.read(expiryServiceProvider),
    repository: ref.read(expiryRepositoryProvider),
    notificationService: ref.read(expiryNotificationServiceProvider),
  );
});


// ============================================================
// ALL PANTRY ITEMS SORTED BY EXPIRY
// ============================================================

final expiryItemsProvider =
    Provider<List<PantryItem>>((ref) {
  final itemsAsync = ref.watch(pantryItemsProvider);

  return itemsAsync.maybeWhen(
    data: (items) {
      return ref
          .read(expiryServiceProvider)
          .sortByExpiryUrgency(items);
    },
    orElse: () => const [],
  );
});


// ============================================================
// EXPIRED ITEMS
// ============================================================

final expiredItemsProvider =
    Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref
      .read(expiryServiceProvider)
      .expiredItems(items);
});


// ============================================================
// EXPIRING SOON
// ============================================================

final expiringSoonItemsProvider =
    Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref
      .read(expiryServiceProvider)
      .expiringSoonItems(items);
});


// ============================================================
// FRESH ITEMS
// ============================================================

final freshItemsProvider =
    Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref
      .read(expiryServiceProvider)
      .freshItems(items);
});


// ============================================================
// ITEMS WITHOUT EXPIRY
// ============================================================

final unknownExpiryItemsProvider =
    Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref
      .read(expiryServiceProvider)
      .itemsWithoutExpiry(items);
});


// ============================================================
// SUMMARY
// ============================================================

final expirySummaryProvider =
    Provider<
      ({int total, int expired, int expiringSoon, int fresh, int unknown})
    >((ref) {
      final items = ref
          .watch(pantryItemsProvider)
          .maybeWhen(
            data: (items) => items,
            orElse: () => const <PantryItem>[],
          );

      return ref.read(expiryServiceProvider).buildSummary(items);
    });

/// Status filter for the expiry list. This is separate from urgency sorting.
enum ExpiryStatusFilter { all, fresh, expiringSoon, expired }

class ExpiryStatusFilterNotifier extends Notifier<ExpiryStatusFilter> {
  @override
  ExpiryStatusFilter build() => ExpiryStatusFilter.all;

  void select(ExpiryStatusFilter filter) {
    state = state == filter ? ExpiryStatusFilter.all : filter;
  }
}

final expiryStatusFilterProvider =
    NotifierProvider<ExpiryStatusFilterNotifier, ExpiryStatusFilter>(
      ExpiryStatusFilterNotifier.new,
    );

// Apply the selected status filter without modifying the original
// Firestore-backed expiry list.
final filteredExpiryItemsProvider = Provider<List<PantryItem>>((ref) {
  final loadedItems = ref.watch(expiryItemsProvider);
  final statusFilter = ref.watch(expiryStatusFilterProvider);
  final statusMatched = loadedItems
      .where((item) => item.matchesExpiryStatusFilter(statusFilter))
      .toList(growable: false);

  return ref.read(expiryServiceProvider).sortByExpiryUrgency(statusMatched);
});

// Group the already filtered expiry list into priority sections without
// modifying the Firestore-backed items.
final groupedExpiryItemsProvider = Provider<ExpiryPriorityGroups>((ref) {
  final filteredItems = ref.watch(filteredExpiryItemsProvider);
  return ref.read(expiryServiceProvider).groupByPriority(filteredItems);
});

/// Counts shown on the status labels, taken from the full summary so a
/// selected filter cannot change them.
int expiryStatusFilterCount(
  ({int total, int expired, int expiringSoon, int fresh, int unknown}) summary,
  ExpiryStatusFilter filter,
) {
  return switch (filter) {
    ExpiryStatusFilter.all =>
      summary.fresh + summary.expiringSoon + summary.expired,
    ExpiryStatusFilter.fresh => summary.fresh,
    ExpiryStatusFilter.expiringSoon => summary.expiringSoon,
    ExpiryStatusFilter.expired => summary.expired,
  };
}

extension on PantryItem {
  bool matchesExpiryStatusFilter(ExpiryStatusFilter filter) {
    return switch (filter) {
      ExpiryStatusFilter.all => expiryDate != null,
      ExpiryStatusFilter.fresh => expiryStatus == ExpiryStatus.fresh,
      ExpiryStatusFilter.expiringSoon =>
        expiryStatus == ExpiryStatus.expiringSoon,
      ExpiryStatusFilter.expired => expiryStatus == ExpiryStatus.expired,
    };
  }
}

/// Items that require smart-alert attention.
///
/// Includes:
/// - expired items
/// - items expiring today
/// - items expiring within 3 days
///
/// They are sorted by urgency so the most urgent item appears first.
final smartAlertItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  final service = ref.read(expiryServiceProvider);

  final attentionItems =
      service.attentionItems(items);

  return service.sortByExpiryUrgency(
    attentionItems,
  );
});


// ============================================================
// FIRESTORE EXPIRY ALERTS
// ============================================================

final expiryAlertsProvider =
    FutureProvider<List<ExpiryAlert>>((ref) {
  return ref
      .read(expiryRepositoryProvider)
      .fetchAlerts();
});


// ============================================================
// MAP PANTRY ITEM ID → EXPIRY ALERT
//
// This is the important part.
//
// Example:
//
// pantry item ID:
// ABC123
//
// corresponding expiry alert:
// alert.id = XYZ789
//
// The screen can now use:
// alert.id
//
// for Update and Stop Tracking.
// ============================================================

final expiryAlertByItemIdProvider =
    Provider<Map<String, ExpiryAlert>>((ref) {
  final alertsAsync =
      ref.watch(expiryAlertsProvider);

  return alertsAsync.maybeWhen(
    data: (alerts) {
      return {
        for (final alert in alerts)
          alert.itemId: alert,
      };
    },
    orElse: () => const <String, ExpiryAlert>{},
  );
});


// ============================================================
// CREATE / UPDATE EXPIRY ALERT
// ============================================================

final saveExpiryAlertProvider =
    Provider<Future<void> Function(ExpiryAlert alert)>(
  (ref) {
    return (ExpiryAlert alert) async {
      await ref
          .read(expiryRepositoryProvider)
          .saveAlert(alert);

      ref.invalidate(expiryAlertsProvider);
    };
  },
);


// ============================================================
// SYNCHRONIZE EXPIRY ALERTS
// ============================================================

final synchronizeExpiryAlertsProvider =
    Provider<Future<void> Function(List<PantryItem>)>(
  (ref) {
    return (List<PantryItem> items) async {
      await ref
          .read(expiryAlertServiceProvider)
          .synchronizeAlerts(items);

      ref.invalidate(expiryAlertsProvider);
    };
  },
);


// ============================================================
// MARK ALERT AS READ
// ============================================================

final markExpiryAlertAsReadProvider =
    Provider<Future<void> Function(String alertId)>(
  (ref) {
    return (String alertId) async {
      await ref
          .read(expiryRepositoryProvider)
          .markAlertAsRead(alertId);

      ref.invalidate(expiryAlertsProvider);
    };
  },
);


// ============================================================
// STOP TRACKING / DELETE EXPIRY ALERT
// ============================================================

final deleteExpiryAlertProvider =
    Provider<Future<void> Function(String alertId)>(
  (ref) {
    return (String alertId) async {
      await ref
          .read(expiryRepositoryProvider)
          .deleteAlert(alertId);

      ref.invalidate(expiryAlertsProvider);
    };
  },
);