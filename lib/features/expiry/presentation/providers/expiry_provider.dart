import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../domain/services/expiry_service.dart';

final expiryServiceProvider = Provider<ExpiryService>((ref) {
  return const ExpiryService();
});

/// All pantry items sorted by expiry urgency.
final expiryItemsProvider = Provider<List<PantryItem>>((ref) {
  final itemsAsync = ref.watch(pantryItemsProvider);

  return itemsAsync.maybeWhen(
    data: (items) => ref
        .read(expiryServiceProvider)
        .sortByExpiryUrgency(items),
    orElse: () => const [],
  );
});

/// Items that have already expired.
final expiredItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref.watch(pantryItemsProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref.read(expiryServiceProvider).expiredItems(items);
});

/// Items expiring today or within the configured expiry window.
final expiringSoonItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref.watch(pantryItemsProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref.read(expiryServiceProvider).expiringSoonItems(items);
});

/// Items with a valid expiry date that are not expiring soon.
final freshItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref.watch(pantryItemsProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref.read(expiryServiceProvider).freshItems(items);
});

/// Items that do not have an expiry date.
final unknownExpiryItemsProvider = Provider<List<PantryItem>>((ref) {
  final items = ref.watch(pantryItemsProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  return ref.read(expiryServiceProvider).itemsWithoutExpiry(items);
});

/// Summary counts for the expiry dashboard.
final expirySummaryProvider = Provider<
    ({
      int total,
      int expired,
      int expiringSoon,
      int fresh,
      int unknown,
    })>((ref) {
  final items = ref.watch(pantryItemsProvider).maybeWhen(
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
  final items = ref.watch(pantryItemsProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <PantryItem>[],
      );

  final service = ref.read(expiryServiceProvider);

  final attentionItems = service.attentionItems(items);

  return service.sortByExpiryUrgency(attentionItems);
});