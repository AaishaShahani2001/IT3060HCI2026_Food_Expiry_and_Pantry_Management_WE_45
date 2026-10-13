import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_scope.dart';

/// An SDK-boundary fake for tests only. No Firebase project is contacted.
class FakeShoppingFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final committedBatches = <List<String>>[];
  final _listeners =
      <String, Set<StreamController<QuerySnapshot<Map<String, dynamic>>>>>{};
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
  int transactionCalls = 0;
  int _nextId = 0;
  bool _transactionBusy = false;
  Completer<void>? _transactionIdle;

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
    while (_transactionBusy) {
      await _transactionIdle!.future;
    }
    _transactionBusy = true;
    _transactionIdle = Completer<void>();
    transactionCalls++;
    final transaction = _Transaction(this);
    try {
      final value = await transactionHandler(transaction);
      final createsDocument = transaction.writes.keys.any(
        (path) => !documents.containsKey(path),
      );
      if (createsDocument) addCalls++;
      await addGate;
      if (createsDocument && addError != null) {
        throw addError!;
      }
      for (final entry in transaction.writes.entries) {
        documents[entry.key] = Map.of(entry.value);
        _notifyDocument(entry.key);
      }
      return value;
    } finally {
      _transactionBusy = false;
      _transactionIdle!.complete();
    }
  }

  void seed(String uid, String id, String name, {bool purchased = false}) {
    seedCollection('users/$uid/shopping_items', id, name, purchased: purchased);
  }

  void seedCollection(
    String collectionPath,
    String id,
    String name, {
    bool purchased = false,
  }) {
    final path = '$collectionPath/$id';
    documents[path] = {'name': name, 'quantity': 2, 'isPurchased': purchased};
    _notifyDocument(path);
  }

  QuerySnapshot<Map<String, dynamic>> _snapshot(String path) {
    final docs = [
      for (final entry in documents.entries)
        if (entry.key.startsWith('$path/') &&
            !entry.key.substring(path.length + 1).contains('/'))
          _QueryDocument(entry.key.split('/').last, Map.of(entry.value)),
    ];
    return _Snapshot(docs);
  }

  void _notifyDocument(String documentPath) {
    final separator = documentPath.lastIndexOf('/');
    if (separator < 0) return;
    final collectionPath = documentPath.substring(0, separator);
    final snapshot = _snapshot(collectionPath);
    for (final listener in List.of(_listeners[collectionPath] ?? const {})) {
      if (!listener.isClosed) listener.add(snapshot);
    }
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
    store._notifyDocument(reference.path);
    return reference;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.readCalls++;
    await store.readGate;
    if (store.readError case final error?) throw error;
    return store._snapshot(path);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
    controller = StreamController<QuerySnapshot<Map<String, dynamic>>>(
      sync: true,
      onListen: () async {
        store.readCalls++;
        await store.readGate;
        if (store.readError case final error?) {
          controller.addError(error);
          return;
        }
        (store._listeners[path] ??= {}).add(controller);
        controller.add(store._snapshot(path));
      },
      onCancel: () => store._listeners[path]?.remove(controller),
    );
    return controller.stream;
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
    store._notifyDocument(path);
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

// DocumentSnapshot is intentionally faked at the SDK boundary in tests.
// ignore: subtype_of_sealed_class
class _DocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _DocumentSnapshot(this.reference, Map<String, dynamic>? value)
    : value = value == null ? null : Map.of(value);

  @override
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? value;

  @override
  String get id => reference.id;

  @override
  bool get exists => value != null;

  @override
  Map<String, dynamic>? data() => value;
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
      store._notifyDocument(path);
    }
    store.committedBatches.add(List.of(paths));
    store.afterCommit?.call();
  }
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);

  final FakeShoppingFirestore store;
  final writes = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final reference =
        documentReference as DocumentReference<Map<String, dynamic>>;
    return _DocumentSnapshot(
          reference,
          writes[reference.path] ?? store.documents[reference.path],
        )
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    writes[documentReference.path] = Map.of(data as Map<String, dynamic>);
    return this;
  }
}

class ShoppingTestSession {
  ShoppingTestSession({
    FakeShoppingFirestore? store,
    String? initialUid = 'alice',
  }) : store = store ?? FakeShoppingFirestore(),
       uid = initialUid {
    if (initialUid != null) {
      _scopes[initialUid] = ShoppingScope.personal(initialUid);
    }
    repository = ShoppingListRepository(
      firestore: this.store,
      currentUid: () => uid,
      scopeStream: _watchScope,
    );
  }

  final FakeShoppingFirestore store;
  final changes = StreamController<String?>.broadcast(sync: true);
  final _scopes = <String, ShoppingScope>{};
  final _scopeChanges = <String, StreamController<ShoppingScope>>{};
  String? uid;
  late final ShoppingListRepository repository;

  Stream<String?> auth() {
    StreamSubscription<String?>? subscription;
    late final StreamController<String?> controller;
    controller = StreamController<String?>(
      sync: true,
      onListen: () {
        controller.add(uid);
        subscription = changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  void changeUser(String? value) {
    uid = value;
    if (value != null) {
      _scopes.putIfAbsent(value, () => ShoppingScope.personal(value));
    }
    changes.add(value);
  }

  Stream<ShoppingScope> _watchScope(String userId) {
    final changes = _scopeChanges[userId] ??=
        StreamController<ShoppingScope>.broadcast();
    StreamSubscription<ShoppingScope>? subscription;
    late final StreamController<ShoppingScope> controller;
    controller = StreamController<ShoppingScope>(
      sync: true,
      onListen: () {
        controller.add(_scopes[userId] ?? ShoppingScope.personal(userId));
        subscription = changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  void changeScope(ShoppingScope scope) {
    _scopes[scope.actorUid] = scope;
    (_scopeChanges[scope.actorUid] ??= StreamController.broadcast()).add(scope);
  }
}
