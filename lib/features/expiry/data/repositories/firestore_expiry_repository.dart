import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/expiry_repository.dart';

class FirestoreExpiryRepository implements ExpiryRepository {
  FirestoreExpiryRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final Map<String, ExpiryAlert> _localAlerts = {};

  CollectionReference<Map<String, dynamic>> get _alertsCollection =>
      _firestore.collection('expiry_alerts');

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  Future<List<ExpiryAlert>> fetchAlerts() async {
    final userId = _currentUserId;

    if (userId == null) {
      return _localAlerts.values.toList();
    }

    try {
      final snapshot = await _alertsCollection
          .where('userId', isEqualTo: userId)
          .get();

      final firestoreAlerts = snapshot.docs
          .map((document) => ExpiryAlert.fromMap(document.id, document.data()))
          .toList();

      final map = <String, ExpiryAlert>{};
      for (final a in firestoreAlerts) {
        map[a.itemId] = a;
        map[a.id] = a;
      }
      for (final a in _localAlerts.values) {
        map[a.itemId] = a;
        map[a.id] = a;
      }

      return map.values.toList();
    } catch (e) {
      return _localAlerts.values.toList();
    }
  }

  @override
  Future<void> saveAlert(ExpiryAlert alert) async {
    _localAlerts[alert.itemId] = alert;
    _localAlerts[alert.id] = alert;

    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    final alertToSave = alert.userId.isEmpty ? alert.copyWith(userId: userId) : alert;

    try {
      await _alertsCollection
          .doc(alertToSave.id)
          .set(alertToSave.toMap(), SetOptions(merge: true));
    } catch (e) {
      // Ignore or log error gracefully
    }
  }

  @override
  Future<void> markAlertAsRead(String alertId) async {
    final existing = _localAlerts[alertId];
    if (existing != null) {
      _localAlerts[alertId] = existing.copyWith(isRead: true);
      _localAlerts[existing.itemId] = existing.copyWith(isRead: true);
    }

    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    try {
      final document = _alertsCollection.doc(alertId);
      final snapshot = await document.get();

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data();

      if (data == null || data['userId'] != userId) {
        return;
      }

      await document.update({'isRead': true});
    } catch (e) {
      // Ignore or log error gracefully
    }
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    final alert = _localAlerts.remove(alertId);
    if (alert != null) {
      _localAlerts.remove(alert.itemId);
    }

    final userId = _currentUserId;

    if (userId == null) {
      return;
    }

    try {
      final document = _alertsCollection.doc(alertId);
      final snapshot = await document.get();

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data();

      if (data == null || data['userId'] != userId) {
        return;
      }

      await document.delete();
    } catch (e) {
      // Ignore or log error gracefully
    }
  }
}
