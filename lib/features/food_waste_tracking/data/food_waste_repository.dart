import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/auth_service.dart';
import '../models/automatic_waste_candidate.dart';
import '../models/food_waste_record.dart';
import '../models/waste_scope.dart';
import '../models/waste_summary.dart';

typedef WasteScopeStream = Stream<WasteScope> Function(String uid);

class FoodWasteRepository {
  FoodWasteRepository({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    WasteScopeStream? scopeStream,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ?? (() => AuthService.instance.currentUser?.uid),
       _scopeStream = scopeStream,
       _injectedAuthUsesPersonalScope =
           scopeStream == null && currentUid != null;

  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;
  final WasteScopeStream? _scopeStream;
  final bool _injectedAuthUsesPersonalScope;
  WasteScope? _currentScope;

  bool isCurrentUser(String uid) => _validSegment(uid) && _currentUid() == uid;

  bool isCurrentScope(WasteScope scope) =>
      isCurrentUser(scope.actorUid) &&
      _validScope(scope) &&
      _currentScope == scope;

  void clearCurrentScope() => _currentScope = null;

  bool _validSegment(String value) =>
      value.trim().isNotEmpty &&
      !value.contains('/') &&
      value != '.' &&
      value != '..';

  bool _validScope(WasteScope scope) {
    try {
      if (scope.isShared) {
        WasteScope.shared(
          actorUid: scope.actorUid,
          pantryId: scope.pantryId ?? '',
        );
      } else {
        WasteScope.personal(actorUid: scope.actorUid);
      }
      return true;
    } on ArgumentError {
      return false;
    }
  }

  void _checkActor(WasteScope scope) {
    if (!isCurrentUser(scope.actorUid) || !_validScope(scope)) {
      throw const WasteScopeChangedException();
    }
  }

  void _checkScope(WasteScope scope) {
    if (!isCurrentScope(scope)) throw const WasteScopeChangedException();
  }

  Stream<WasteScope?> watchScope(String uid) {
    if (!isCurrentUser(uid)) return const Stream<WasteScope?>.empty();
    final injected = _scopeStream;
    if (injected != null) {
      return Stream<WasteScope?>.multi((output) {
        final subscription = injected(uid).listen((scope) {
          final previousScope = _currentScope;
          _currentScope = null;
          if (previousScope != null && previousScope != scope) {
            output.add(null);
          }
          if (!isCurrentUser(scope.actorUid) ||
              scope.actorUid != uid ||
              !_validScope(scope)) {
            output.addError(const WasteScopeChangedException());
            return;
          }
          _currentScope = scope;
          output.add(scope);
        }, onError: output.addError);
        output.onCancel = () => unawaited(subscription.cancel());
      });
    }
    if (_injectedAuthUsesPersonalScope) {
      final scope = WasteScope.personal(actorUid: uid);
      _currentScope = scope;
      return Stream<WasteScope?>.value(scope);
    }
    return _watchProfileScope(uid);
  }

  Stream<WasteScope?> _watchProfileScope(String uid) => Stream.multi((output) {
    var generation = 0;
    var canceled = false;
    final subscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (profile) {
            final currentGeneration = ++generation;
            final previousScope = _currentScope;
            final hintedScope = _profileScopeHint(uid, profile.data());
            _currentScope = null;
            if (previousScope != null &&
                (hintedScope == null || hintedScope != previousScope)) {
              output.add(null);
            }
            unawaited(
              _resolveProfileScope(uid, profile.data()).then(
                (scope) {
                  if (canceled ||
                      currentGeneration != generation ||
                      !isCurrentUser(uid)) {
                    return;
                  }
                  _currentScope = scope;
                  output.add(scope);
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!canceled && currentGeneration == generation) {
                    output.addError(error, stackTrace);
                  }
                },
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            _currentScope = null;
            output.addError(error, stackTrace);
          },
        );
    output.onCancel = () {
      canceled = true;
      generation++;
      unawaited(subscription.cancel());
    };
  });

  WasteScope? _profileScopeHint(String uid, Map<String, dynamic>? profile) {
    final pantryType =
        (profile?['pantryType'] as String?)?.trim().toLowerCase() ?? 'personal';
    if (pantryType == 'personal') {
      return WasteScope.personal(actorUid: uid);
    }
    final pantryId = (profile?['pantryId'] as String?)?.trim();
    if ((pantryType == 'family' || pantryType == 'shared') &&
        pantryId != null &&
        _validSegment(pantryId)) {
      return WasteScope.shared(actorUid: uid, pantryId: pantryId);
    }
    return null;
  }

  Future<WasteScope> _resolveProfileScope(
    String uid,
    Map<String, dynamic>? profile,
  ) async {
    if (!isCurrentUser(uid)) throw const WasteScopeChangedException();
    final pantryType =
        (profile?['pantryType'] as String?)?.trim().toLowerCase() ?? 'personal';
    if (pantryType == 'personal') {
      return WasteScope.personal(actorUid: uid);
    }
    if (pantryType != 'family' && pantryType != 'shared') {
      throw StateError('No active Waste Tracker scope is available.');
    }

    String? pantryId = (profile?['pantryId'] as String?)?.trim();
    if (pantryId == null || pantryId.isEmpty) {
      final memberships = await _firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (memberships.docs.isEmpty) {
        throw StateError(
          'Your shared pantry membership could not be verified.',
        );
      }
      pantryId = memberships.docs.first.reference.parent.parent?.id;
    }
    if (pantryId == null || !_validSegment(pantryId)) {
      throw StateError('No active Waste Tracker scope is available.');
    }

    final pantry = _firestore.collection('pantries').doc(pantryId);
    final pantryDocument = await pantry.get();
    final member = await pantry.collection('members').doc(uid).get();
    if (!isCurrentUser(uid)) throw const WasteScopeChangedException();
    if (!pantryDocument.exists ||
        !member.exists ||
        member.data()?['uid'] != uid) {
      throw StateError('Your shared pantry membership could not be verified.');
    }
    return WasteScope.shared(actorUid: uid, pantryId: pantryId);
  }

  CollectionReference<Map<String, dynamic>> _records(WasteScope scope) {
    _checkScope(scope);
    return _firestore.collection(scope.collectionPath);
  }

  CollectionReference<Map<String, dynamic>> _recordsForCompensation(
    WasteScope scope,
  ) {
    _checkActor(scope);
    return _firestore.collection(scope.collectionPath);
  }

  void _checkId(String? id) {
    if (id == null || !_validSegment(id)) {
      throw ArgumentError('Invalid record ID.');
    }
  }

  List<FoodWasteRecord> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      newestWasteFirst(
        snapshot.docs
            .map((doc) => FoodWasteRecord.fromMap(doc.id, doc.data()))
            .where((record) => !record.notWasted),
      );

  Stream<List<FoodWasteRecord>> watch(WasteScope scope) {
    final collection = _records(scope);
    return collection.snapshots().map((snapshot) {
      _checkScope(scope);
      return _decode(snapshot);
    });
  }

  Future<List<FoodWasteRecord>> load(WasteScope scope) async {
    final snapshot = await _records(scope).get();
    _checkScope(scope);
    return _decode(snapshot);
  }

  Future<FoodWasteRecord> create(
    WasteScope scope,
    FoodWasteRecord record,
  ) async {
    if (record.id != null) throw ArgumentError('Expected a new record.');
    final stamped = record.copyWith(
      itemName: record.itemName.trim(),
      recordedByUid: scope.actorUid,
    );
    final document = await _records(scope).add(stamped.toMap());
    return stamped.copyWith(id: document.id);
  }

  Future<FoodWasteRecord> update(
    WasteScope scope,
    FoodWasteRecord record,
  ) async {
    _checkId(record.id);
    record.validate();
    final document = _records(scope).doc(record.id);
    late FoodWasteRecord saved;
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(document);
      final existing = snapshot.data();
      if (!snapshot.exists || existing == null) {
        throw StateError('The record no longer exists.');
      }
      final existingActor = existing['recordedByUid'];
      final data = record.copyWith(itemName: record.itemName.trim()).toMap();
      if (existingActor is String) {
        data['recordedByUid'] = existingActor;
      } else {
        data.remove('recordedByUid');
      }
      transaction.update(document, data);
      saved = FoodWasteRecord.fromMap(record.id!, data);
    });
    _checkScope(scope);
    return saved;
  }

  Future<void> delete(WasteScope scope, String id) async {
    _checkId(id);
    final document = _records(scope).doc(id);
    await (_firestore.batch()..delete(document)).commit();
    _checkScope(scope);
  }

  Future<void> deleteMany(WasteScope scope, Set<String> ids) async {
    if (ids.isEmpty) throw ArgumentError('Expected Waste record IDs.');
    for (final id in ids) {
      _checkId(id);
    }
    final records = _records(scope);
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(records.doc(id));
    }
    await batch.commit();
    _checkScope(scope);
  }

  Future<void> rollbackCreated(
    WasteScope capturedScope,
    FoodWasteRecord record,
  ) async {
    _checkId(record.id);
    if (record.recordedByUid != capturedScope.actorUid) {
      throw StateError(
        'Only the newly created Waste record can be rolled back.',
      );
    }
    final document = _recordsForCompensation(capturedScope).doc(record.id);
    await (_firestore.batch()..delete(document)).commit();
    _checkActor(capturedScope);
  }

  Future<bool> reconcileAutomatic(
    WasteScope scope,
    Iterable<AutomaticWasteCandidate> candidates,
  ) async {
    _checkScope(scope);
    var changed = false;
    for (final candidate in candidates) {
      if (candidate.scope != scope) throw const WasteScopeChangedException();
      final record = candidate.record.copyWith(recordedByUid: scope.actorUid);
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
      final document = _records(scope).doc(record.id);
      final created = await _firestore.runTransaction<bool>((
        transaction,
      ) async {
        final existing = await transaction.get(document);
        if (existing.exists) return false;
        transaction.set(document, record.toMap());
        return true;
      });
      _checkScope(scope);
      changed = changed || created;
    }
    return changed;
  }

  Future<void> markNotWasted(WasteScope scope, FoodWasteRecord record) async {
    _checkId(record.id);
    if (!record.isAutomaticExpiry || record.notWasted) {
      throw ArgumentError('Expected an automatic waste record.');
    }
    final document = _records(scope).doc(record.id);
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
    _checkScope(scope);
  }
}
