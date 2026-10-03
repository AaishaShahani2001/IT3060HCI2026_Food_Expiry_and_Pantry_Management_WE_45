import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pantry/data/services/pantry_firestore_service.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/domain/utils/expiry_status.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../models/automatic_waste_candidate.dart';
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
  PantryUnit.boxes => 'box',
};

class PantryWasteSource {
  const PantryWasteSource(this.uid, this.item);
  final String uid;
  final PantryItem item;

  double estimatedValueFor(double quantity) {
    if (!quantity.isFinite || quantity <= 0) return 0;
    final value = calculateRemainingValue(item.copyWith(quantity: quantity));
    return value.isFinite && value >= 0 ? value : 0;
  }

  bool isExpiredAt(DateTime now) =>
      item.expiryDate != null &&
      ExpiryStatusHelper.fromDate(
            item.expiryDate!.toLocal(),
            referenceDate: now.toLocal(),
          ) ==
          ExpiryStatus.expired;

  FoodWasteRecord draft(DateTime now) {
    return FoodWasteRecord(
      itemName: item.name,
      quantity: item.quantity,
      unit: wasteUnitFor(item.unit),
      reason: 'Expired',
      estimatedValue: estimatedValueFor(item.quantity),
      wastedAt: now,
      source: manualPantryWasteSource,
      sourcePantryItemId: item.firestoreId,
    );
  }

  AutomaticWasteCandidate automaticCandidate() {
    final pantryItemId = item.firestoreId!;
    final expiryDate = item.expiryDate!;
    final value = calculateRemainingValue(item);
    final normalizedExpiry = wasteExpiryDate(expiryDate);
    return AutomaticWasteCandidate(
      uid: uid,
      record: FoodWasteRecord(
        id: automaticWasteEventId(pantryItemId, normalizedExpiry),
        itemName: item.name,
        quantity: item.quantity,
        unit: wasteUnitFor(item.unit),
        reason: 'Expired',
        estimatedValue: value.isFinite && value >= 0 ? value : 0,
        wastedAt: wasteExpiryEventTime(normalizedExpiry),
        source: automaticExpiryWasteSource,
        sourcePantryItemId: pantryItemId,
        sourceExpiryDate: normalizedExpiry,
      ),
    );
  }
}

final activeWastePantryProvider = Provider<AsyncValue<List<PantryWasteSource>>>(
  (ref) {
    final auth = ref.watch(wasteAuthUidProvider);
    final uid = auth.asData?.value;
    if (auth.isLoading ||
        uid == null ||
        !ref.watch(foodWasteRepositoryProvider).isCurrentUser(uid)) {
      return const AsyncData([]);
    }
    return ref
        .watch(wastePantryItemsProvider(uid))
        .whenData(
          (items) => [
            for (final item in items)
              if (item.isConnectedToFirestore &&
                  item.quantity.isFinite &&
                  item.quantity > 0)
                PantryWasteSource(uid, item),
          ],
        );
  },
);

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
                    item.expiryDate != null &&
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

/// Coordinates a saved manual Waste record with Pantry's transaction-backed
/// decrement. The two documents are not one atomic transaction; callers must
/// compensate by deleting the newly-created Waste record if this step fails.
class PantryWasteActions {
  PantryWasteActions(this.ref);

  final Ref ref;

  Future<double> decrementSavedQuantity(
    PantryWasteSource source,
    FoodWasteRecord saved,
  ) async {
    if (!ref.read(foodWasteRepositoryProvider).isCurrentUser(source.uid) ||
        ref.read(wasteAuthUidProvider).asData?.value != source.uid ||
        saved.id == null ||
        !ref
            .read(foodWasteProvider)
            .requireValue
            .any((record) => identical(record, saved)) ||
        saved.sourcePantryItemId != source.item.firestoreId) {
      throw const PantryAccessDeniedException();
    }

    final items = ref.read(wastePantryItemsProvider(source.uid)).asData?.value;
    final current = items
        ?.where((item) => item.firestoreId == source.item.firestoreId)
        .firstOrNull;
    if (current == null) {
      throw PantryItemNotFoundException(source.item.firestoreId ?? '');
    }
    if (current.name != source.item.name ||
        current.unit != source.item.unit ||
        saved.unit != wasteUnitFor(current.unit) ||
        !saved.quantity.isFinite ||
        saved.quantity <= 0 ||
        saved.quantity > current.quantity) {
      throw InsufficientPantryQuantityException(
        requested: saved.quantity,
        available: current.quantity,
      );
    }

    return ref
        .read(wastePantryServiceProvider)
        .decrementItemQuantity(
          userId: source.uid,
          itemId: current.firestoreId!,
          amount: saved.quantity,
        );
  }
}
