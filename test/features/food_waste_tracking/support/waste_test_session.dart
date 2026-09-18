import 'dart:async';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/data/food_waste_repository.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_firestore_service.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
// Reuse the existing SDK-boundary fake without changing Shopping List tests.
import '../../shopping_list/support/fake_firestore.dart';

final wasteTestNow = DateTime(2026, 9, 16, 12);
FoodWasteRecord draft({
  String name = 'Apples',
  double quantity = 2,
  String unit = 'pcs',
  double value = 100,
  DateTime? date,
}) => FoodWasteRecord(
  itemName: name,
  quantity: quantity,
  unit: unit,
  reason: 'Expired',
  estimatedValue: value,
  wastedAt: date ?? wasteTestNow,
);

class WasteTestSession {
  final pantry = FakeWastePantryService();
  final store = FakeShoppingFirestore();
  final changes = StreamController<String?>.broadcast();
  String? uid = 'alice';
  late final repository = FoodWasteRepository(
    firestore: store,
    currentUid: () => uid,
  );
  void seed(String uid, String id, FoodWasteRecord record) {
    store.documents['users/$uid/waste_records/$id'] = record.toMap();
  }

  Stream<String?> auth() async* {
    yield uid;
    yield* changes.stream;
  }

  void changeUser(String? value) {
    uid = value;
    changes.add(value);
  }
}

class FakeWastePantryService implements PantryFirestoreService {
  final items = <String, List<PantryItem>>{};
  final _listeners = <String, Set<MultiStreamController<List<PantryItem>>>>{};
  final reductions = <(String, String, double)>[];
  Object? failure;
  Future<void>? gate;
  void seed(String uid, PantryItem item) {
    items[uid] = [...?items[uid]?.where((r) => r.id != item.id), item];
    for (final listener
        in _listeners[uid] ?? <MultiStreamController<List<PantryItem>>>{}) {
      listener.add(List.of(items[uid]!));
    }
  }

  @override
  Stream<List<PantryItem>> watchPantryItems({required String userId}) =>
      Stream.multi((controller) {
        (_listeners[userId] ??= {}).add(controller);
        controller.add(List.of(items[userId] ?? []));
        controller.onCancel = () => _listeners[userId]?.remove(controller);
      });
  @override
  Future<double> markItemConsumed({
    required String userId,
    required String itemId,
    required double consumedQuantity,
  }) async {
    reductions.add((userId, itemId, consumedQuantity));
    if (gate != null) await gate;
    if (failure != null) throw failure!;
    final item = items[userId]!.singleWhere((r) => r.firestoreId == itemId);
    if (consumedQuantity > item.quantity || consumedQuantity <= 0) {
      throw StateError('Invalid quantity');
    }
    final remaining = item.quantity - consumedQuantity;
    seed(userId, item.copyWith(quantity: remaining));
    return remaining;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
