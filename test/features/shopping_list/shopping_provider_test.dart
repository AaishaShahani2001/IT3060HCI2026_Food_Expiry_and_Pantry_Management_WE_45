import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';

import 'support/fake_firestore.dart';

void main() {
  late ShoppingTestSession session;
  late ProviderContainer container;

  setUp(() {
    session = ShoppingTestSession();
    container = ProviderContainer(
      overrides: [
        shoppingListRepositoryProvider.overrideWithValue(session.repository),
        shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
      ],
    );
    container.listen(shoppingListProvider, (previous, next) {});
  });

  tearDown(() async {
    container.dispose();
    await session.changes.close();
  });

  Future<List<ShoppingItem>> load() =>
      container.read(shoppingListProvider.future);
  ShoppingListNotifier notifier() =>
      container.read(shoppingListProvider.notifier);
  List<ShoppingItem> items() =>
      container.read(shoppingListProvider).requireValue;

  test('initial load, add and reload use the repository', () async {
    session.store.seed('alice', 'milk', 'Milk');
    expect((await load()).single.name, 'Milk');
    await notifier().addItem(const ShoppingItem(name: 'Bread', quantity: 1));
    expect(items().map((item) => item.name), ['Milk', 'Bread']);
    expect(items().last.id, isNotNull);
    await notifier().reload();
    expect(items().length, 2);
  });

  test('failed add retains existing items', () async {
    session.store.seed('alice', 'milk', 'Milk');
    await load();
    session.store.addError = StateError('Test save failure');
    await expectLater(
      notifier().addItem(const ShoppingItem(name: 'Bread', quantity: 1)),
      throwsStateError,
    );
    expect(items().single.name, 'Milk');
  });

  test('local edit and purchase keep ID and do not persist', () async {
    session.store.seed('alice', 'milk', 'Milk');
    await load();
    notifier().togglePurchased('milk', true);
    notifier().updateItem(
      'milk',
      const ShoppingItem(name: 'Fresh Milk', quantity: 3, isPurchased: true),
    );
    expect(items().single.id, 'milk');
    expect(items().single.isPurchased, isTrue);
    expect(items().single.name, 'Fresh Milk');
    expect(
      session.store.documents['users/alice/shopping_items/milk']!['name'],
      'Milk',
    );
    await notifier().reload();
    expect(items().single.name, 'Milk');
    expect(items().single.isPurchased, isFalse);
  });

  test(
    'delete waits for commit; duplicate request blocked; reload stays empty',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      await load();
      final gate = Completer<void>();
      session.store.deleteGate = gate.future;
      final deletion = notifier().deleteItem('milk');
      expect(items().single.name, 'Milk');
      await expectLater(notifier().deleteItem('milk'), throwsStateError);
      gate.complete();
      await deletion;
      expect(items(), isEmpty);
      expect(session.store.commitCalls, 1);
      await notifier().reload();
      expect(items(), isEmpty);
    },
  );

  test('failed multi-delete keeps all items and exact error', () async {
    session.store.seed('alice', 'milk', 'Milk');
    session.store.seed('alice', 'bread', 'Bread');
    await load();
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    session.store.deleteError = error;
    await expectLater(
      notifier().deleteItems(['milk', 'bread']),
      throwsA(same(error)),
    );
    expect(items().length, 2);
  });

  test(
    'partial batch failure does not partially remove provider data',
    () async {
      final ids = List.generate(405, (index) => 'item-$index');
      for (final id in ids) {
        session.store.seed('alice', id, id);
      }
      await load();
      session.store.deleteError = StateError('Second batch failed');
      session.store.failCommitNumber = 2;
      await expectLater(
        notifier().deleteItems(ids),
        throwsA(isA<ShoppingListDeleteException>()),
      );
      expect(items().length, 405);
      await notifier().reload();
      expect(items().length, 5);
    },
  );

  test(
    'account switch reloads; sign-out clears state and blocks writes',
    () async {
      session.store.seed('alice', 'milk', 'Alice milk');
      session.store.seed('bob', 'bread', 'Bob bread');
      await load();
      session.changeUser('bob');
      await container.pump();
      await load();
      expect(items().single.name, 'Bob bread');
      session.changeUser(null);
      await container.pump();
      await load();
      expect(items(), isEmpty);
      await expectLater(
        notifier().addItem(const ShoppingItem(name: 'No user', quantity: 1)),
        throwsStateError,
      );
    },
  );

  test('old pending save cannot inject an item into a new account', () async {
    session.store.seed('bob', 'bread', 'Bob bread');
    await load();
    final gate = Completer<void>();
    session.store.addGate = gate.future;
    final saving = notifier().addItem(
      const ShoppingItem(name: 'Alice milk', quantity: 2),
    );
    session.changeUser('bob');
    await container.pump();
    await load();
    expect(items().single.name, 'Bob bread');
    gate.complete();
    await saving;
    expect(items().single.name, 'Bob bread');
    expect(
      session.store.documents.containsKey(
        'users/bob/shopping_items/generated-1',
      ),
      isFalse,
    );
  });

  test(
    'changing auth before stream delivery cannot write under a stale UID',
    () async {
      await load();
      session.uid = 'bob';
      await expectLater(
        notifier().addItem(const ShoppingItem(name: 'Milk', quantity: 1)),
        throwsStateError,
      );
      expect(session.store.addCalls, 0);
    },
  );

  test('a stale read cannot replace the new account list', () async {
    session.store.seed('alice', 'milk', 'Alice milk');
    session.store.seed('bob', 'bread', 'Bob bread');
    final gate = Completer<void>();
    session.store.readGate = gate.future;
    // Start the first read, then let only the new account read finish.
    await container.pump();
    session.store.readGate = null;
    session.changeUser('bob');
    await container.pump();
    await load();
    expect(items().single.name, 'Bob bread');
    gate.complete();
    await container.pump();
    expect(items().single.name, 'Bob bread');
  });

  test(
    'a pending old-account delete cannot remove a new account item with the same ID',
    () async {
      session.store.seed('alice', 'milk', 'Alice milk');
      session.store.seed('bob', 'milk', 'Bob milk');
      await load();
      final gate = Completer<void>();
      session.store.deleteGate = gate.future;
      final deleting = notifier().deleteItem('milk');
      session.changeUser('bob');
      await container.pump();
      await load();
      gate.complete();
      await deleting;
      expect(items().single.name, 'Bob milk');
      expect(
        session.store.documents.containsKey('users/bob/shopping_items/milk'),
        isTrue,
      );
    },
  );
}
