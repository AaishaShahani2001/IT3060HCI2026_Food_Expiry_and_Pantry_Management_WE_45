import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../data/repositories/firestore_expiry_repository.dart';
import '../../domain/repositories/expiry_repository.dart';
import '../../domain/services/expiry_alert_service.dart';
import '../../domain/services/expiry_service.dart';

final expiryServiceProvider = Provider<ExpiryService>((ref) {
  return const ExpiryService();
});

final expiryRepositoryProvider = Provider<ExpiryRepository>((ref) {
  return FirestoreExpiryRepository();
});

final expiryAlertServiceProvider = Provider<ExpiryAlertService>((ref) {
  return ExpiryAlertService(
    expiryService: ref.read(expiryServiceProvider),
    repository: ref.read(expiryRepositoryProvider),
  );
});

/// All pantry items sorted by expiry urgency.
final expiryItemsProvider = Provider<List<PantryItem>>((ref) {
  final itemsAsync = ref.watch(pantryItemsProvider);

  return itemsAsync.maybeWhen(
    data: (items) => ref.read(expiryServiceProvider).sortByExpiryUrgency(items),
    orElse: () => const [],
  );
});

/// Items that have already expired.
final expiredItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(data: (items) => items, orElse: () => const <PantryItem>[]);

  return ref.read(expiryServiceProvider).expiredItems(items);
});

/// Items expiring today or within the configured expiry window.
final expiringSoonItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(data: (items) => items, orElse: () => const <PantryItem>[]);

  return ref.read(expiryServiceProvider).expiringSoonItems(items);
});

/// Items with a valid expiry date that are not expiring soon.
final freshItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(data: (items) => items, orElse: () => const <PantryItem>[]);

  return ref.read(expiryServiceProvider).freshItems(items);
});

/// Items that do not have an expiry date.
final unknownExpiryItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref
      .watch(pantryItemsProvider)
      .maybeWhen(data: (items) => items, orElse: () => const <PantryItem>[]);

  return ref.read(expiryServiceProvider).itemsWithoutExpiry(items);
});

/// Summary counts for the expiry dashboard.
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
      .maybeWhen(data: (items) => items, orElse: () => const <PantryItem>[]);

  final service = ref.read(expiryServiceProvider);

  final attentionItems = service.attentionItems(items);

  return service.sortByExpiryUrgency(attentionItems);
});

/// Saved smart expiry alerts from Firestore.
final expiryAlertsProvider = FutureProvider<List<ExpiryAlert>>((ref) {
  return ref.read(expiryRepositoryProvider).fetchAlerts();
});

/// Synchronizes the current pantry expiry state with Firestore.
///
/// Only items requiring attention are saved as smart alerts.
final synchronizeExpiryAlertsProvider =
    Provider<Future<void> Function(List<PantryItem>)>((ref) {
      return (List<PantryItem> items) async {
        await ref.read(expiryAlertServiceProvider).synchronizeAlerts(items);

        ref.invalidate(expiryAlertsProvider);
      };
    });

/// Marks a Firestore expiry alert as read.
final markExpiryAlertAsReadProvider =
    Provider<Future<void> Function(String alertId)>((ref) {
      return (String alertId) async {
        await ref.read(expiryRepositoryProvider).markAlertAsRead(alertId);

        ref.invalidate(expiryAlertsProvider);
      };
    });

/// Deletes a Firestore expiry alert.
final deleteExpiryAlertProvider =
    Provider<Future<void> Function(String alertId)>((ref) {
      return (String alertId) async {
        await ref.read(expiryRepositoryProvider).deleteAlert(alertId);

        ref.invalidate(expiryAlertsProvider);
      };
    });
