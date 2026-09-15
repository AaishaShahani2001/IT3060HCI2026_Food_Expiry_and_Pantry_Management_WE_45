import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/expiry_repository.dart';

class FirestoreExpiryRepository implements ExpiryRepository {
  FirestoreExpiryRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _alertsCollection =>
      _firestore.collection('expiry_alerts');

  String get _currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user.uid;
  }

  @override
  Future<List<ExpiryAlert>> fetchAlerts() async {
    final userId = _currentUserId;

    final snapshot = await _alertsCollection
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map((document) => ExpiryAlert.fromMap(document.id, document.data()))
        .toList();
  }

  @override
  Future<void> saveAlert(ExpiryAlert alert) async {
    final userId = _currentUserId;

    if (alert.userId != userId) {
      throw StateError('Expiry alert does not belong to the current user.');
    }

    await _alertsCollection
        .doc(alert.id)
        .set(alert.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> markAlertAsRead(String alertId) async {
    final userId = _currentUserId;

    final document = _alertsCollection.doc(alertId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError('Expiry alert not found.');
    }

    final data = snapshot.data();

    if (data == null || data['userId'] != userId) {
      throw StateError('You do not have permission to update this alert.');
    }

    await document.update({'isRead': true});
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    final userId = _currentUserId;

    final document = _alertsCollection.doc(alertId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data();

    if (data == null || data['userId'] != userId) {
      throw StateError('You do not have permission to delete this alert.');
    }

    await document.delete();
  }
}
