import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

import 'support/fake_firestore.dart';

void main() {
  test(
    'model round-trip persists only the three fields and restores document ID',
    () {
      const item = ShoppingItem(name: 'Milk', quantity: 2, isPurchased: true);
      expect(item.id, isNull);
      expect(item.toMap(), {
        'name': 'Milk',
        'quantity': 2,
        'isPurchased': true,
      });
      final loaded = ShoppingItem.fromMap('milk-id', item.toMap());
      expect(loaded.id, 'milk-id');
      expect(
        loaded.copyWith(name: 'Fresh Milk', quantity: 3).isPurchased,
        isTrue,
      );
      expect(loaded.copyWith(isPurchased: false).id, 'milk-id');
      expect(loaded.copyWith(isPurchased: false).quantity, 2);
    },
  );

  test(
    'model handles absent purchased field and rejects malformed quantities',
    () {
      expect(
        ShoppingItem.fromMap('id', {'name': 'Milk', 'quantity': 2}).isPurchased,
        isFalse,
      );
      for (final quantity in [0, 101, 1.5, '2', null]) {
        expect(
          () => ShoppingItem.fromMap('id', {
            'name': 'Milk',
            'quantity': quantity,
          }),
          throwsFormatException,
        );
      }
    },
  );

  late ShoppingTestSession session;
  setUp(() => session = ShoppingTestSession());
  tearDown(() => session.changes.close());

  test(
    'create and read survive a new repository and are scoped to UID',
    () async {
      session.store.seed('bob', 'other', 'Private item');
      const draft = ShoppingItem(name: ' Milk ', quantity: 2);
      final saved = await session.repository.addShoppingItem('alice', draft);
      expect(saved.id, isNotEmpty);
      expect(saved.name, 'Milk');
      expect(
        session.store.documents['users/alice/shopping_items/${saved.id}'],
        {'name': 'Milk', 'quantity': 2, 'isPurchased': false},
      );
      final reloadedRepository = ShoppingListRepository(
        firestore: session.store,
        currentUid: () => session.uid,
      );
      final items = await reloadedRepository.getShoppingItems('alice');
      expect(items.map((item) => item.name), ['Milk']);
      expect(items.single.id, saved.id);
      expect(
        session.store.documents.containsKey('users/bob/shopping_items/other'),
        isTrue,
      );
    },
  );

  test('wrong or missing UID cannot read, write, or delete', () async {
    const item = ShoppingItem(name: 'Milk', quantity: 2);
    await expectLater(
      session.repository.getShoppingItems('bob'),
      throwsStateError,
    );
    await expectLater(
      session.repository.addShoppingItem('bob', item),
      throwsStateError,
    );
    await expectLater(
      session.repository.deleteShoppingItem('bob', 'id'),
      throwsStateError,
    );
    session.uid = null;
    await expectLater(
      session.repository.getShoppingItems('alice'),
      throwsStateError,
    );
    expect(session.store.readCalls, 0);
    expect(session.store.addCalls, 0);
    expect(session.store.commitCalls, 0);
  });

  test('invalid new items cannot overwrite existing documents', () async {
    await expectLater(
      session.repository.addShoppingItem(
        'alice',
        const ShoppingItem(id: 'id', name: 'Milk', quantity: 2),
      ),
      throwsArgumentError,
    );
    await expectLater(
      session.repository.addShoppingItem(
        'alice',
        const ShoppingItem(name: ' ', quantity: 2),
      ),
      throwsArgumentError,
    );
    expect(session.store.addCalls, 0);
  });

  test(
    'single delete preserves user document and other accounts; reload stays deleted',
    () async {
      session.store.documents['users/alice'] = {'name': 'Alice'};
      session.store.seed('alice', 'milk', 'Milk');
      session.store.seed('bob', 'milk', 'Bob milk');
      await session.repository.deleteShoppingItem('alice', 'milk');
      expect(await session.repository.getShoppingItems('alice'), isEmpty);
      expect(session.store.documents.containsKey('users/alice'), isTrue);
      expect(
        session.store.documents.containsKey('users/bob/shopping_items/milk'),
        isTrue,
      );
    },
  );

  test(
    'multi-delete deduplicates IDs and chunks a list over 500 items',
    () async {
      final ids = List.generate(805, (index) => 'item-$index');
      for (final id in ids) {
        session.store.seed('alice', id, id);
      }
      await session.repository.deleteShoppingItems('alice', [
        ...ids,
        ids.first,
      ]);
      expect(session.store.committedBatches.map((batch) => batch.length), [
        400,
        400,
        5,
      ]);
      expect(await session.repository.getShoppingItems('alice'), isEmpty);
    },
  );

  test(
    'invalid ID rejects entire operation before any delete; empty IDs no-op',
    () async {
      for (final id in ['', ' ', '../other', 'users/bob', '.', '..']) {
        await expectLater(
          session.repository.deleteShoppingItems('alice', ['valid', id]),
          throwsArgumentError,
        );
      }
      await session.repository.deleteShoppingItems('alice', []);
      expect(session.store.commitCalls, 0);
    },
  );

  test(
    'permission-denied remains exact and atomic batch keeps documents',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Test denial',
      );
      session.store.deleteError = error;
      await expectLater(
        session.repository.deleteShoppingItem('alice', 'milk'),
        throwsA(same(error)),
      );
      expect(
        session.store.documents.containsKey('users/alice/shopping_items/milk'),
        isTrue,
      );
    },
  );

  test(
    'later batch failure reports partial completion and retry is safe',
    () async {
      final ids = List.generate(405, (index) => 'item-$index');
      for (final id in ids) {
        session.store.seed('alice', id, id);
      }
      session.store.deleteError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      session.store.failCommitNumber = 2;
      await expectLater(
        session.repository.deleteShoppingItems('alice', ids),
        throwsA(
          isA<ShoppingListDeleteException>()
              .having(
                (error) => error.deletedItemIds.length,
                'committed count',
                400,
              )
              .having(
                (error) => (error.cause as FirebaseException).code,
                'code',
                'permission-denied',
              ),
        ),
      );
      expect(session.store.documents.length, 5);
      session.store.deleteError = null;
      await session.repository.deleteShoppingItems('alice', ids);
      expect(session.store.documents, isEmpty);
    },
  );

  test('account change between delete batches stops further writes', () async {
    final ids = List.generate(405, (index) => 'item-$index');
    for (final id in ids) {
      session.store.seed('alice', id, id);
    }
    session.store.afterCommit = () => session.uid = 'bob';
    await expectLater(
      session.repository.deleteShoppingItems('alice', ids),
      throwsA(
        isA<ShoppingListDeleteException>().having(
          (error) => error.cause,
          'account change',
          isA<StateError>(),
        ),
      ),
    );
    expect(session.store.commitCalls, 1);
    expect(session.store.documents.length, 5);
  });
}
