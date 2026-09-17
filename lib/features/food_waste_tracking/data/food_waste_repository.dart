import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/auth_service.dart';
import '../models/food_waste_record.dart';
import '../models/waste_summary.dart';

class FoodWasteRepository {
  FoodWasteRepository({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ?? (() => AuthService.instance.currentUser?.uid);
  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;
  bool isCurrentUser(String uid) =>
      uid.isNotEmpty &&
      !uid.contains('/') &&
      uid != '.' &&
      uid != '..' &&
      _currentUid() == uid;
  void _checkUser(String uid) {
    if (!isCurrentUser(uid)) throw StateError('Account changed.');
  }

  CollectionReference<Map<String, dynamic>> _records(String uid) {
    _checkUser(uid);
    return _firestore.collection('users').doc(uid).collection('waste_records');
  }

  void _checkId(String? id) {
    if (id == null ||
        id.trim().isEmpty ||
        id.contains('/') ||
        id == '.' ||
        id == '..') {
      throw ArgumentError('Invalid record ID.');
    }
  }

  Future<List<FoodWasteRecord>> load(String uid) async {
    final snapshot = await _records(uid).get();
    _checkUser(uid);
    return newestWasteFirst(
      snapshot.docs.map((doc) => FoodWasteRecord.fromMap(doc.id, doc.data())),
    );
  }

  Future<FoodWasteRecord> create(String uid, FoodWasteRecord record) async {
    if (record.id != null) throw ArgumentError('Expected a new record.');
    final data = record.toMap();
    final document = await _records(uid).add(data);
    return record.copyWith(id: document.id, itemName: record.itemName.trim());
  }

  Future<void> update(String uid, FoodWasteRecord record) async {
    _checkId(record.id);
    final data = record.toMap();
    // Never recreate an already deleted document during edit.
    await _records(uid).doc(record.id).update(data);
  }

  Future<void> delete(String uid, String id) async {
    _checkId(id);
    final document = _records(uid).doc(id);
    final batch = _firestore.batch()..delete(document);
    await batch.commit();
  }
}
