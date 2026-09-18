import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pantry/data/services/pantry_firestore_service.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/domain/utils/expiry_status.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../models/food_waste_record.dart';
import 'food_waste_provider.dart';

final wastePantryServiceProvider = Provider<PantryFirestoreService>(
  (ref) => ref.watch(pantryFirestoreServiceProvider),
);

// Reuse Pantry's service, not its untagged shared list: that list can retain the
// previous account while switching subscriptions. A UID-keyed stream prevents
// stale data from becoming a suggestion for the next account. No new schema.
final wastePantryItemsProvider = StreamProvider.autoDispose
    .family<List<PantryItem>, String>(
      (ref, uid) =>
          ref.watch(wastePantryServiceProvider).watchPantryItems(userId: uid),
    );

String wasteUnitFor(PantryUnit unit) => switch (unit) {
  PantryUnit.items => 'pcs',
  PantryUnit.kg => 'kg',
  PantryUnit.g => 'g',
  PantryUnit.liters => 'L',
  PantryUnit.ml => 'ml',
  PantryUnit.packs => 'pack',
  PantryUnit.bottles => 'bottle',
};

class PantryWasteSource {
  const PantryWasteSource(this.uid, this.item);
  final String uid;
  final PantryItem item;
  FoodWasteRecord draft(DateTime now) {
    final value = item.unitPrice * item.quantity;
    return FoodWasteRecord(
      itemName: item.name,
      quantity: item.quantity,
      unit: wasteUnitFor(item.unit),
      reason: 'Expired',
      estimatedValue: value.isFinite && value >= 0 ? value : 0,
      wastedAt: now,
      source: 'pantry',
      sourcePantryItemId: item.firestoreId,
    );
  }
}

final expiredWastePantryProvider =
    Provider<AsyncValue<List<PantryWasteSource>>>((ref) {
      final auth = ref.watch(wasteAuthUidProvider);
      final uid = auth.asData?.value;
      if (auth.isLoading ||
          uid == null ||
          !ref.watch(foodWasteRepositoryProvider).isCurrentUser(uid)) {
        return const AsyncData([]);
      }
      final now = ref.watch(wasteClockProvider)().toLocal();
      return ref
          .watch(wastePantryItemsProvider(uid))
          .whenData(
            (items) => [
              for (final item in items)
                if (item.isConnectedToFirestore &&
                    item.quantity.isFinite &&
                    item.quantity > 0 &&
                    ExpiryStatusHelper.fromDate(
                          item.expiryDate?.toLocal(),
                          referenceDate: now,
                        ) ==
                        ExpiryStatus.expired)
                  PantryWasteSource(uid, item),
            ],
          );
    });

final pantryWasteActionsProvider = Provider((ref) => PantryWasteActions(ref));

class PantryWasteActions {
  PantryWasteActions(this.ref);
  final Ref ref;
  final _applied = <String>{};
  bool _busy = false;

  Future<void> removeSavedQuantity(
    PantryWasteSource source,
    FoodWasteRecord saved,
  ) async {
    final key = '${source.uid}/${saved.id}';
    if (_busy || _applied.contains(key)) {
      throw StateError('Pantry update already handled.');
    }
    if (!ref.read(foodWasteRepositoryProvider).isCurrentUser(source.uid) ||
        ref.read(wasteAuthUidProvider).asData?.value != source.uid ||
        saved.id == null ||
        !ref
            .read(foodWasteProvider)
            .requireValue
            .any((r) => identical(r, saved)) ||
        saved.sourcePantryItemId != source.item.firestoreId) {
      throw StateError('Account or saved record changed.');
    }
    final items = ref.read(wastePantryItemsProvider(source.uid)).asData?.value;
    final current = items
        ?.where((item) => item.firestoreId == source.item.firestoreId)
        .firstOrNull;
    if (current == null ||
        current.name != source.item.name ||
        current.unit != source.item.unit ||
        saved.unit != wasteUnitFor(current.unit) ||
        !saved.quantity.isFinite ||
        saved.quantity <= 0 ||
        // Pantry stores stock to two decimals; do not silently round a waste
        // quantity into no stock reduction or a larger reduction.
        (saved.quantity * 100 - (saved.quantity * 100).roundToDouble()).abs() >
            0.000001 ||
        saved.quantity > current.quantity ||
        ref.read(pantryPendingQuantitiesProvider).containsKey(current.id) ||
        ref.read(pantryBusyItemIdsProvider).contains(current.id)) {
      throw StateError('Pantry quantity or unit changed.');
    }
    _busy = true;
    final busy = ref.read(pantryBusyItemIdsProvider.notifier);
    busy.start(current.id);
    try {
      // Pantry's existing flow re-reads available stock and keeps zero-stock
      // items. Never delete a newly replenished document using an old snapshot.
      // This remains Pantry's get+update flow, not a cross-device transaction.
      await ref
          .read(wastePantryServiceProvider)
          .markItemConsumed(
            userId: source.uid,
            itemId: current.firestoreId!,
            consumedQuantity: saved.quantity,
          );
      _applied.add(key);
      // Both Pantry and this UID-scoped list receive the existing live stream.
    } finally {
      _busy = false;
      if (ref.mounted) busy.stop(current.id);
    }
  }
}
