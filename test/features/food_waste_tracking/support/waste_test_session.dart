import 'dart:async';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/data/food_waste_repository.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_firestore_service.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/removed_pantry_item.dart';
import 'fake_waste_firestore.dart';

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
  final store = FakeWasteFirestore();
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
  final decrements = <(String, String, double)>[];
  Object? decrementError;
  Future<void>? decrementGate;
  void Function()? beforeDecrement;
  int markItemConsumedCalls = 0;
  int markAsUsedUpCalls = 0;
  int deletePantryItemCalls = 0;

  void seed(String uid, PantryItem item) {
    items[uid] = [...?items[uid]?.where((r) => r.id != item.id), item];
    for (final listener
        in _listeners[uid] ?? <MultiStreamController<List<PantryItem>>>{}) {
      listener.add(List.of(items[uid]!));
    }
  }

  void remove(String uid, String firestoreId) {
    items[uid] = [
      for (final item in items[uid] ?? const <PantryItem>[])
        if (item.firestoreId != firestoreId) item,
    ];
    _publish(uid);
  }

  void _publish(String uid) {
    for (final listener
        in _listeners[uid] ?? <MultiStreamController<List<PantryItem>>>{}) {
      listener.add(List.of(items[uid] ?? const <PantryItem>[]));
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
  Future<double> decrementItemQuantity({
    required String userId,
    required String itemId,
    required double amount,
  }) async {
    decrements.add((userId, itemId, amount));
    await decrementGate;
    beforeDecrement?.call();
    if (decrementError case final error?) throw error;
    final matches = (items[userId] ?? const <PantryItem>[])
        .where((item) => item.firestoreId == itemId)
        .toList();
    if (matches.isEmpty) throw PantryItemNotFoundException(itemId);
    final item = matches.single;
    if (amount > item.quantity) {
      throw InsufficientPantryQuantityException(
        requested: amount,
        available: item.quantity,
      );
    }
    final remaining = double.parse((item.quantity - amount).toStringAsFixed(2));
    seed(userId, item.copyWith(quantity: remaining));
    return remaining;
  }

  @override
  Future<double> markItemConsumed({
    required String userId,
    required String itemId,
    required double consumedQuantity,
  }) {
    markItemConsumedCalls++;
    throw UnsupportedError('Waste Tracker must use decrementItemQuantity.');
  }

  @override
  Future<RemovedPantryItem> markAsUsedUp({
    required String userId,
    required PantryItem item,
    required int originalIndex,
  }) {
    markAsUsedUpCalls++;
    throw UnsupportedError('Waste Tracker must not invoke Used Up.');
  }

  @override
  Future<void> deletePantryItem({
    required String userId,
    required String itemId,
  }) {
    deletePantryItemCalls++;
    throw UnsupportedError('Waste Tracker must not delete Pantry items.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
