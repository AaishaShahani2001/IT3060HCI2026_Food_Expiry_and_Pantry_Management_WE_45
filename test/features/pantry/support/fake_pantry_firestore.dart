import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firestore stand-in for pantry quantity tests. A transaction read can be
/// invalidated once, which forces [FirebaseFirestore.runTransaction] to run
/// the callback again against the updated document.
class FakePantryFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final versions = <String, int>{};
  final transactionUpdates = <Map<String, dynamic>>[];
  int transactionAttempts = 0;
  int directUpdateCalls = 0;
  int deleteCalls = 0;
  _Contention? _pendingContention;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      transactionAttempts = attempt;
      final transaction = _PantryTransaction(this);
      final result = await transactionHandler(transaction);
      try {
        transaction.commit();
        return result;
      } on _PantryTransactionConflict {
        if (attempt == maxAttempts) rethrow;
      }
    }
    throw StateError('Transaction failed after $maxAttempts attempts.');
  }

  /// After the next transactional read of [path], replace that document so
  /// the in-flight transaction must retry.
  void contendOnNextTransactionRead(String path, Map<String, dynamic> data) {
    _pendingContention = _Contention(path, Map<String, dynamic>.of(data));
  }
}

class _Contention {
  const _Contention(this.path, this.data);
  final String path;
  final Map<String, dynamic> data;
}

class _PantryTransactionConflict implements Exception {
  const _PantryTransactionConflict();
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final FakePantryFirestore store;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/${path ?? 'generated'}');
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final FakePantryFirestore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final data = store.documents[path];
    return _PantryDocumentSnapshot(
      id,
      data == null ? null : Map<String, dynamic>.of(data),
    );
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.directUpdateCalls++;
    final document = store.documents[path];
    if (document == null) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
    }
    document.addAll(data.cast<String, dynamic>());
  }

  @override
  Future<void> delete() async {
    store.deleteCalls++;
    store.documents.remove(path);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');
}

// ignore: subtype_of_sealed_class
class _PantryDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _PantryDocumentSnapshot(this.id, Map<String, dynamic>? data)
    : _data = data == null ? null : Map<String, dynamic>.of(data);
  @override
  final String id;
  final Map<String, dynamic>? _data;
  @override
  bool get exists => _data != null;
  @override
  Map<String, dynamic>? data() =>
      _data == null ? null : Map<String, dynamic>.of(_data);
}

class _PantryTransaction extends Fake implements Transaction {
  _PantryTransaction(this.store);
  final FakePantryFirestore store;
  final _readVersions = <String, int>{};
  final _updates = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final path = documentReference.path;
    final version = store.versions[path] ?? 0;
    _readVersions[path] = version;
    final current = store.documents[path];
    final snapshot = current == null ? null : Map<String, dynamic>.of(current);

    final contention = store._pendingContention;
    if (contention != null && contention.path == path) {
      store._pendingContention = null;
      store.documents[path] = Map<String, dynamic>.of(contention.data);
      store.versions[path] = version + 1;
    }

    return _PantryDocumentSnapshot(documentReference.id, snapshot)
        as DocumentSnapshot<T>;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    _updates[documentReference.path] = data.cast<String, dynamic>();
    return this;
  }

  void commit() {
    for (final entry in _readVersions.entries) {
      if ((store.versions[entry.key] ?? 0) != entry.value) {
        throw const _PantryTransactionConflict();
      }
    }
    for (final entry in _updates.entries) {
      final document = store.documents[entry.key];
      if (document == null) {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
      }
      document.addAll(entry.value);
      store.versions[entry.key] = (store.versions[entry.key] ?? 0) + 1;
      store.transactionUpdates.add(Map<String, dynamic>.of(entry.value));
    }
  }
}
