import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';

/// An SDK-boundary fake for tests only. No Firebase project is contacted.
class FakeShoppingFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final committedBatches = <List<String>>[];
  Future<void>? readGate;
  Future<void>? addGate;
  Future<void>? deleteGate;
  Future<void>? updateGate;
  Object? readError;
  Object? addError;
  Object? deleteError;
  Object? updateError;
  int updateCalls = 0;
  int? failCommitNumber;
  void Function()? afterCommit;
  int readCalls = 0;
  int addCalls = 0;
  int commitCalls = 0;
  int _nextId = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  WriteBatch batch() => _Batch(this);

  void seed(String uid, String id, String name, {bool purchased = false}) {
    documents['users/$uid/shopping_items/$id'] = {
      'name': name,
      'quantity': 2,
      'isPurchased': purchased,
    };
  }
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final FakeShoppingFirestore store;
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
    final docs = [
      for (final entry in store.documents.entries)
        if (entry.key.startsWith('$path/') &&
            !entry.key.substring(path.length + 1).contains('/'))
          _QueryDocument(entry.key.split('/').last, Map.of(entry.value)),
    ];
    await store.readGate;
    if (store.readError case final error?) throw error;
    return _Snapshot(docs);
  }
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final FakeShoppingFirestore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;

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

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// QueryDocumentSnapshot is intentionally faked at the SDK boundary in tests.
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

class _Batch extends Fake implements WriteBatch {
  _Batch(this.store);
  final FakeShoppingFirestore store;
  final paths = <String>[];

  @override
  void delete(DocumentReference reference) => paths.add(reference.path);

  @override
  Future<void> commit() async {
    final number = ++store.commitCalls;
    await store.deleteGate;
    if (store.deleteError != null &&
        (store.failCommitNumber == null || store.failCommitNumber == number)) {
      throw store.deleteError!;
    }
    for (final path in paths) {
      store.documents.remove(path);
    }
    store.committedBatches.add(List.of(paths));
    store.afterCommit?.call();
  }
}

class ShoppingTestSession {
  final store = FakeShoppingFirestore();
  final changes = StreamController<String?>.broadcast();
  String? uid = 'alice';
  late final repository = ShoppingListRepository(
    firestore: store,
    currentUid: () => uid,
  );

  Stream<String?> auth() async* {
    yield uid;
    yield* changes.stream;
  }

  void changeUser(String? value) {
    uid = value;
    changes.add(value);
  }
}
