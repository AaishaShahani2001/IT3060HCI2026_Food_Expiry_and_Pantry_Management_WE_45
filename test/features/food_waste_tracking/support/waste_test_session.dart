import 'dart:async';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/data/food_waste_repository.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
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
