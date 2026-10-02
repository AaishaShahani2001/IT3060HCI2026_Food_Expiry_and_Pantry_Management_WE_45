import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pantry/domain/models/pantry_item.dart';
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
        ({
          int total,
          int expired,
          int expiringSoon,
          int fresh,
          int unknown,
        })>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref
      .read(expiryServiceProvider)
      .buildSummary(items);
});


// ============================================================
// SMART ALERT ITEMS
// ============================================================

final smartAlertItemsProvider =
    Provider<List<PantryItem>>((ref) {
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