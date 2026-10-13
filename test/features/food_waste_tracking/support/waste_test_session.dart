import 'dart:async';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/data/food_waste_repository.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_scope.dart';
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
  WasteTestSession({
    FakeWasteFirestore? store,
    FakeWastePantryService? pantry,
    String? initialUid = 'alice',
  }) : store = store ?? FakeWasteFirestore(),
       pantry = pantry ?? FakeWastePantryService(),
       uid = initialUid {
    if (initialUid != null) {
      _scopes[initialUid] = WasteScope.personal(actorUid: initialUid);
      this.pantry.setScope(_scopes[initialUid]!);
    }
    repository = FoodWasteRepository(
      firestore: this.store,
      currentUid: () => uid,
      scopeStream: _watchScope,
    );
  }

  final FakeWastePantryService pantry;
  final FakeWasteFirestore store;
  final changes = StreamController<String?>.broadcast(sync: true);
  final _scopes = <String, WasteScope>{};
  final _scopeChanges = <String, StreamController<WasteScope>>{};
  String? uid;
  late final FoodWasteRepository repository;

  void seed(String uid, String id, FoodWasteRecord record) {
    store.documents['users/$uid/waste_records/$id'] = record.toMap();
    store.notifyDocument('users/$uid/waste_records/$id');
  }

  void seedScope(WasteScope scope, String id, FoodWasteRecord record) {
    final path = '${scope.collectionPath}/$id';
    store.documents[path] = record.toMap();
    store.notifyDocument(path);
  }

  WasteScope scopeFor(String userId) =>
      _scopes[userId] ?? WasteScope.personal(actorUid: userId);

  Stream<String?> auth() {
    StreamSubscription<String?>? subscription;
    late final StreamController<String?> controller;
    controller = StreamController<String?>(
      sync: true,
      onListen: () {
        controller.add(uid);
        subscription = changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  void changeUser(String? value) {
    uid = value;
    if (value != null) {
      _scopes.putIfAbsent(value, () => WasteScope.personal(actorUid: value));
      pantry.setScope(_scopes[value]!);
    }
    changes.add(value);
  }

  Stream<WasteScope> _watchScope(String userId) {
    final changes = _scopeChanges[userId] ??=
        StreamController<WasteScope>.broadcast(sync: true);
    StreamSubscription<WasteScope>? subscription;
    late final StreamController<WasteScope> controller;
    controller = StreamController<WasteScope>(
      sync: true,
      onListen: () {
        controller.add(scopeFor(userId));
        subscription = changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  void changeScope(WasteScope scope) {
    _scopes[scope.actorUid] = scope;
    pantry.setScope(scope);
    (_scopeChanges[scope.actorUid] ??= StreamController<WasteScope>.broadcast(
      sync: true,
    )).add(scope);
  }

  void failScope(String userId, Object error) {
    (_scopeChanges[userId] ??= StreamController<WasteScope>.broadcast(
      sync: true,
    )).addError(error);
  }

  Future<void> dispose() async {
    await changes.close();
    for (final controller in _scopeChanges.values) {
      await controller.close();
    }
  }
}

class FakeWastePantryService implements PantryFirestoreService {
  final items = <String, List<PantryItem>>{};
  final _listeners = <String, Set<MultiStreamController<List<PantryItem>>>>{};
  final _storageKeys = <String, String>{};
  final decrements = <(String, String, double)>[];
  Object? decrementError;
  Future<void>? decrementGate;
  Future<void>? watchGate;
  void Function()? beforeDecrement;
  int markItemConsumedCalls = 0;
  int markAsUsedUpCalls = 0;
  int deletePantryItemCalls = 0;

  String _key(String uid) => _storageKeys[uid] ?? uid;

  void setScope(WasteScope scope) {
    _storageKeys[scope.actorUid] = scope.isShared
        ? 'pantry:${scope.pantryId}'
        : scope.actorUid;
    _publish(scope.actorUid);
  }

  void seed(String uid, PantryItem item) {
    final key = _key(uid);
    items[key] = [...?items[key]?.where((r) => r.id != item.id), item];
    _publishStorage(key);
  }

  void remove(String uid, String firestoreId) {
    final key = _key(uid);
    items[key] = [
      for (final item in items[key] ?? const <PantryItem>[])
        if (item.firestoreId != firestoreId) item,
    ];
    _publishStorage(key);
  }

  void _publish(String uid) {
    for (final listener
        in _listeners[uid] ?? <MultiStreamController<List<PantryItem>>>{}) {
      listener.add(List.of(items[_key(uid)] ?? const <PantryItem>[]));
    }
  }

  void _publishStorage(String key) {
    final users = <String>{
      ..._listeners.keys.where((uid) => _key(uid) == key),
      ..._storageKeys.entries
          .where((entry) => entry.value == key)
          .map((entry) => entry.key),
    };
    for (final uid in users) {
      _publish(uid);
    }
  }

  @override
  Stream<List<PantryItem>> watchPantryItems({required String userId}) =>
      Stream.multi((controller) {
        var canceled = false;
        void attach() {
          if (canceled) return;
          (_listeners[userId] ??= {}).add(controller);
          controller.add(List.of(items[_key(userId)] ?? []));
        }

        final gate = watchGate;
        if (gate == null) {
          attach();
        } else {
          unawaited(() async {
            try {
              await gate;
              attach();
            } catch (error, stackTrace) {
              if (!canceled) controller.addError(error, stackTrace);
            }
          }());
        }
        controller.onCancel = () {
          canceled = true;
          _listeners[userId]?.remove(controller);
        };
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
    final key = _key(userId);
    final matches = (items[key] ?? const <PantryItem>[])
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
