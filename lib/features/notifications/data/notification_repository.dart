import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/app_notification.dart';
import '../domain/notification_planner.dart';
import '../domain/notification_repository.dart';

/// `users/{userId}/notifications/{alertKey}` plus stock-threshold memory at
/// `users/{userId}/notificationMeta/stock`.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _batchLimit = 400;

  CollectionReference<Map<String, dynamic>> _notifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  DocumentReference<Map<String, dynamic>> _stock(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notificationMeta')
        .doc('stock');
  }

  @override
  Stream<List<AppNotification>> watchActive(String userId, {int limit = 50}) {
    return _watch(userId, limit: limit);
  }

  @override
  Stream<List<AppNotification>> watchAll(String userId) {
    return _watch(userId, limit: null);
  }

  /// Order by createdAt only. Combining that sort with a deletedAt filter
  /// needs a composite index that is not created in Firebase yet.
  Stream<List<AppNotification>> _watch(String userId, {required int? limit}) {
    Query<Map<String, dynamic>> query = _notifications(
      userId,
    ).orderBy('createdAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map((snapshot) {
      final items = <AppNotification>[];
      for (final doc in snapshot.docs) {
        final parsed = AppNotification.tryParse(doc.id, doc.data());
        if (parsed != null && parsed.deletedAt == null) {
          items.add(parsed);
        }
      }
      return List<AppNotification>.unmodifiable(items);
    });
  }

  @override
  Future<Set<String>> fetchAlertKeys(String userId) async {
    try {
      final snapshot = await _notifications(userId).get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (_) {
      throw const NotificationFailure();
    }
  }

  @override
  Future<StockMemory> fetchStockMemory(String userId) async {
    try {
      final snapshot = await _stock(userId).get();
      final data = snapshot.data();
      if (data == null) return const StockMemory();
      return StockMemory(
        armedItemIds: _stringSet(data['armedItemIds']),
        lowStockVersions: _versionMap(data['lowStockVersions']),
      );
    } catch (_) {
      throw const NotificationFailure();
    }
  }

  @override
  Future<void> saveStockMemory(String userId, StockMemory memory) async {
    try {
      final versions = memory.lowStockVersions.map(
        (key, value) => MapEntry(key, value),
      );
      await _stock(userId).set({
        'armedItemIds': memory.armedItemIds.toList()..sort(),
        'lowStockVersions': versions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      throw const NotificationFailure();
    }
  }

  @override
  Future<void> createIfAbsent(AppNotification notification) async {
    final doc = _notifications(notification.userId).doc(notification.alertKey);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(doc);
        if (snapshot.exists) return;
        transaction.set(doc, {
          'userId': notification.userId,
          'type': notification.type.name,
          'title': notification.title,
          'message': notification.message,
          'pantryItemId': notification.pantryItemId,
          'pantryItemName': notification.pantryItemName,
          'pantryScope': notification.pantryScope,
          'pantryName': notification.pantryName,
          'expiryDate': notification.expiryDate == null
              ? null
              : Timestamp.fromDate(notification.expiryDate!),
          'alertKey': notification.alertKey,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'readAt': null,
          'deletedAt': null,
        });
      });
    } catch (_) {
      throw const NotificationFailure();
    }
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) {
    return _update(userId, notificationId, {
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markAsUnread(String userId, String notificationId) {
    return _update(userId, notificationId, {'isRead': false, 'readAt': null});
  }

  @override
  Future<void> deleteNotification(String userId, String notificationId) {
    return _update(userId, notificationId, {
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markAllAsRead(String userId) {
    return _updateActive(userId, unreadOnly: true, delete: false);
  }

  @override
  Future<void> deleteAllNotifications(String userId) {
    return _updateActive(userId, unreadOnly: false, delete: true);
  }

  Future<void> _update(
    String userId,
    String notificationId,
    Map<String, Object?> data,
  ) async {
    try {
      await _notifications(userId).doc(notificationId).update(data);
    } catch (_) {
      throw const NotificationFailure();
    }
  }

  Future<void> _updateActive(
    String userId, {
    required bool unreadOnly,
    required bool delete,
  }) async {
    try {
      final snapshot = await _notifications(
        userId,
      ).where('deletedAt', isNull: true).get();
      final docs = [
        for (final doc in snapshot.docs)
          if (!unreadOnly || doc.data()['isRead'] != true) doc,
      ];
      for (var start = 0; start < docs.length; start += _batchLimit) {
        final batch = _firestore.batch();
        final end = start + _batchLimit;
        final slice = docs.sublist(
          start,
          end > docs.length ? docs.length : end,
        );
        for (final doc in slice) {
          batch.update(
            doc.reference,
            delete
                ? {'deletedAt': FieldValue.serverTimestamp()}
                : {'isRead': true, 'readAt': FieldValue.serverTimestamp()},
          );
        }
        await batch.commit();
      }
    } catch (_) {
      throw const NotificationFailure();
    }
  }
}

Set<String> _stringSet(Object? raw) {
  if (raw is! List) return const {};
  return {
    for (final value in raw)
      if (value is String && value.isNotEmpty) value,
  };
}

Map<String, int> _versionMap(Object? raw) {
  if (raw is! Map) return const {};
  final versions = <String, int>{};
  raw.forEach((key, value) {
    if (key is! String || key.isEmpty) return;
    if (value is int) {
      versions[key] = value;
    } else if (value is num && value.isFinite) {
      versions[key] = value.toInt();
    }
  });
  return versions;
}
