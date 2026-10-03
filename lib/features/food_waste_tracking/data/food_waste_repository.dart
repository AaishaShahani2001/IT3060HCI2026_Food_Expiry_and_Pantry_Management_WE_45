import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/auth_service.dart';
import '../models/automatic_waste_candidate.dart';
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
      snapshot.docs
          .map((doc) => FoodWasteRecord.fromMap(doc.id, doc.data()))
          .where((record) => !record.notWasted),
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

  Future<bool> reconcileAutomatic(
    String uid,
    Iterable<AutomaticWasteCandidate> candidates,
  ) async {
    _checkUser(uid);
    var changed = false;
    for (final candidate in candidates) {
      if (candidate.uid != uid) throw StateError('Account changed.');
      final record = candidate.record;
      _checkId(record.id);
      record.validate();
      if (!record.isAutomaticExpiry ||
          record.id !=
              automaticWasteEventId(
                record.sourcePantryItemId!,
                record.sourceExpiryDate!,
              )) {
        throw ArgumentError('Invalid automatic waste event.');
      }
      final document = _records(uid).doc(record.id);
      final created = await _firestore.runTransaction<bool>((
        transaction,
      ) async {
        final existing = await transaction.get(document);
        if (existing.exists) return false;
        transaction.set(document, record.toMap());
        return true;
      });
      _checkUser(uid);
      changed = changed || created;
    }
    return changed;
  }

  Future<void> markNotWasted(String uid, FoodWasteRecord record) async {
    _checkId(record.id);
    if (!record.isAutomaticExpiry || record.notWasted) {
      throw ArgumentError('Expected an automatic waste record.');
    }
    final document = _records(uid).doc(record.id);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(document);
      final data = snapshot.data();
      if (!snapshot.exists ||
          data == null ||
          data['source'] != automaticExpiryWasteSource) {
        throw StateError('Automatic waste record changed.');
      }
      transaction.update(document, {'notWasted': true});
    });
    _checkUser(uid);
  }
}
