import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/expiry_alert_id.dart';
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
      return dedupeExpiryAlerts(_localAlerts.values);
    }

    try {
      final snapshot = await _alertsCollection
          .where('userId', isEqualTo: userId)
          .get();

      final firestoreAlerts = snapshot.docs
          .map((document) => ExpiryAlert.fromMap(document.id, document.data()))
          .toList();

      return dedupeExpiryAlerts([
        ...firestoreAlerts,
        ..._localAlerts.values.where(
          (alert) => alert.userId.isEmpty || alert.userId == userId,
        ),
      ]);
    } catch (e) {
      return dedupeExpiryAlerts(_localAlerts.values);
    }
  }

  @override
  Future<void> saveAlert(ExpiryAlert alert) async {
    if (alert.itemId.trim().isEmpty) return;

    final userId = _currentUserId;
    final alertToSave = userId == null
        ? alert
        : scopedExpiryAlert(alert: alert, userId: userId);
    _rememberLocally(alertToSave);

    if (userId == null) {
      return;
    }

    try {
      await _alertsCollection
          .doc(alertToSave.id)
          .set(alertToSave.toMap(), SetOptions(merge: true));
      await _deleteOwnedLegacy(userId, alertToSave.itemId);
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
      final updated = await _updateOwned(userId, alertId, {'isRead': true});
      final itemId = updated ?? _itemIdFromAlertId(userId, alertId);
      if (itemId == null) return;

      final canonical = buildExpiryAlertId(userId, itemId);
      if (canonical != alertId) {
        await _updateOwned(userId, canonical, {'isRead': true});
      }
      if (itemId != alertId && itemId != canonical) {
        await _updateOwned(userId, itemId, {'isRead': true});
      }
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
      final removedItemId = await _deleteOwned(userId, alertId);
      final itemId = removedItemId ?? _itemIdFromAlertId(userId, alertId);
      if (itemId == null) return;

      final canonical = buildExpiryAlertId(userId, itemId);
      if (canonical != alertId) {
        await _deleteOwned(userId, canonical);
      }
      await _deleteOwnedLegacy(userId, itemId);
    } catch (e) {
      // Ignore or log error gracefully
    }
  }

  void _rememberLocally(ExpiryAlert alert) {
    if (alert.itemId.isNotEmpty) {
      _localAlerts[alert.itemId] = alert;
    }
    _localAlerts[alert.id] = alert;
  }

  /// Deletes `expiry_alerts/{itemId}` only when that document belongs to
  /// [userId]. Another user's document at the same id is left untouched.
  Future<void> _deleteOwnedLegacy(String userId, String itemId) async {
    final canonical = buildExpiryAlertId(userId, itemId);
    if (itemId.isEmpty || itemId == canonical) return;
    await _deleteOwned(userId, itemId);
  }

  Future<String?> _deleteOwned(String userId, String documentId) async {
    if (documentId.isEmpty) return null;
    final snapshot = await _alertsCollection.doc(documentId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null || data['userId'] != userId) return null;
    await snapshot.reference.delete();
    _localAlerts.remove(documentId);
    final itemId = data['itemId'];
    if (itemId is String && itemId == documentId) {
      _localAlerts.remove(itemId);
    }
    return itemId is String && itemId.isNotEmpty ? itemId : null;
  }

  Future<String?> _updateOwned(
    String userId,
    String documentId,
    Map<String, Object> fields,
  ) async {
    if (documentId.isEmpty) return null;
    final snapshot = await _alertsCollection.doc(documentId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null || data['userId'] != userId) return null;
    await snapshot.reference.update(fields);
    final itemId = data['itemId'];
    return itemId is String && itemId.isNotEmpty ? itemId : null;
  }

  /// Item id encoded in `{userId}_{itemId}` when that document was never saved.
  String? _itemIdFromAlertId(String userId, String alertId) {
    final prefix = '${userId}_';
    if (!alertId.startsWith(prefix)) return null;
    final itemId = alertId.substring(prefix.length);
    if (itemId.isEmpty) return null;
    return itemId;
  }
}
