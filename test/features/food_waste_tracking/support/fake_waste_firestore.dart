import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firestore SDK-boundary fake used only by Waste Tracker tests.
class FakeWasteFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  Future<void>? readGate;
  Future<void>? addGate;
  Future<void>? deleteGate;
  Future<void>? updateGate;
  Object? readError;
  Object? addError;
  Object? deleteError;
  Object? updateError;
  Object? transactionError;
  int readCalls = 0;
  int addCalls = 0;
  int updateCalls = 0;
  int commitCalls = 0;
  int transactionCalls = 0;
  int transactionSetCalls = 0;
  int _nextId = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  WriteBatch batch() => _Batch(this);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactionCalls++;
    if (transactionError case final error?) throw error;
    final transaction = _Transaction(this);
    final result = await transactionHandler(transaction);
    transaction.commit();
    return result;
  }
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final FakeWasteFirestore store;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Document(
    store,
    '${this.path}/${path ?? 'generated-${++store._nextId}'}',
  );

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    store.addCalls++;
    final reference = doc();
    await store.addGate;
    if (store.addError case final error?) throw error;
    store.documents[reference.path] = Map.of(data);
    return reference;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.readCalls++;
    await store.readGate;
    if (store.readError case final error?) throw error;
    return _QuerySnapshot([
      for (final entry in store.documents.entries)
        if (entry.key.startsWith('$path/') &&
            !entry.key.substring(path.length + 1).contains('/'))
          _QueryDocument(entry.key.split('/').last, Map.of(entry.value)),
    ]);
  }
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final FakeWasteFirestore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _DocumentSnapshot(id, store.documents[path]);

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.updateCalls++;
    await store.updateGate;
    if (store.updateError case final error?) throw error;
    final document = store.documents[path];
    if (document == null) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
    }
    document.addAll(data.cast<String, dynamic>());
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// ignore: subtype_of_sealed_class
class _QueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDocument(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

// ignore: subtype_of_sealed_class
class _DocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _DocumentSnapshot(this.id, Map<String, dynamic>? data)
    : _data = data == null ? null : Map.of(data);
  @override
  final String id;
  final Map<String, dynamic>? _data;
  @override
  bool get exists => _data != null;
  @override
  Map<String, dynamic>? data() => _data;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);
  final FakeWasteFirestore store;
  final _sets = <String, Map<String, dynamic>>{};
  final _updates = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final data = store.documents[documentReference.path];
    return _DocumentSnapshot(documentReference.id, data) as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? setOptions,
  ]) {
    store.transactionSetCalls++;
    _sets[documentReference.path] = Map<String, dynamic>.from(
      data! as Map<String, dynamic>,
    );
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    if (!store.documents.containsKey(documentReference.path)) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
    }
    _updates[documentReference.path] = data.cast<String, dynamic>();
    return this;
  }

  void commit() {
    for (final entry in _sets.entries) {
      store.documents[entry.key] = Map.of(entry.value);
    }
    for (final entry in _updates.entries) {
      store.documents[entry.key]!.addAll(entry.value);
    }
  }
}

class _Batch extends Fake implements WriteBatch {
  _Batch(this.store);
  final FakeWasteFirestore store;
  final paths = <String>[];

  @override
  void delete(DocumentReference reference) => paths.add(reference.path);

  @override
  Future<void> commit() async {
    store.commitCalls++;
    await store.deleteGate;
    if (store.deleteError case final error?) throw error;
    for (final path in paths) {
      store.documents.remove(path);
    }
  }
}
