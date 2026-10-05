import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_scope.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';

import 'support/fake_firestore.dart';

void main() {
  ProviderContainer containerFor(ShoppingTestSession session) {
    final container = ProviderContainer(
      overrides: [
        shoppingListRepositoryProvider.overrideWithValue(session.repository),
        shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
      ],
    );
    container.listen(shoppingListProvider, (_, _) {});
    return container;
  }

  Future<void> settle(Iterable<ProviderContainer> containers) async {
    for (var index = 0; index < 20; index++) {
      for (final container in containers) {
        await container.pump();
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  List<ShoppingItem> items(ProviderContainer container) =>
      container.read(shoppingListProvider).requireValue;

  test('personal and Family Pantry scopes resolve exact collection paths', () {
    final personal = ShoppingScope.personal('alice');
    final aliceFamily = ShoppingScope.shared(
      actorUid: 'alice',
      pantryId: 'family-123',
    );
    final bobFamily = ShoppingScope.shared(
      actorUid: 'bob',
      pantryId: 'family-123',
    );

    expect(personal.collectionPath, 'users/alice/shopping_items');
    expect(aliceFamily.collectionPath, 'pantries/family-123/shopping_items');
    expect(bobFamily.collectionPath, aliceFamily.collectionPath);
  });

  test('two Family Pantry members observe realtime Shopping CRUD', () async {
    final store = FakeShoppingFirestore();
    final alice = ShoppingTestSession(store: store, initialUid: 'alice')
      ..changeScope(
        ShoppingScope.shared(actorUid: 'alice', pantryId: 'family-123'),
      );
    final bob = ShoppingTestSession(store: store, initialUid: 'bob')
      ..changeScope(
        ShoppingScope.shared(actorUid: 'bob', pantryId: 'family-123'),
      );
    final aliceContainer = containerFor(alice);
    final bobContainer = containerFor(bob);
    addTearDown(() async {
      aliceContainer.dispose();
      bobContainer.dispose();
      await alice.changes.close();
      await bob.changes.close();
    });

    await Future.wait([
      aliceContainer.read(shoppingListProvider.future),
      bobContainer.read(shoppingListProvider.future),
    ]);
    final created = await aliceContainer
        .read(shoppingListProvider.notifier)
        .addItem(const ShoppingItem(name: 'Milk', quantity: 1));
    await settle([aliceContainer, bobContainer]);
    expect(items(bobContainer).single.name, 'Milk');
    await expectLater(
      bobContainer
          .read(shoppingListProvider.notifier)
          .addItem(const ShoppingItem(name: ' milk ', quantity: 1)),
      throwsA(isA<ShoppingDuplicateException>()),
    );

    await bobContainer
        .read(shoppingListProvider.notifier)
        .updateItem(
          created.id!,
          items(bobContainer).single.copyWith(quantity: 4),
        );
    await settle([aliceContainer, bobContainer]);
    expect(items(aliceContainer).single.quantity, 4);

    await bobContainer
        .read(shoppingListProvider.notifier)
        .togglePurchased(created.id!, true);
    await settle([aliceContainer, bobContainer]);
    expect(items(aliceContainer).single.isPurchased, isTrue);

    await bobContainer
        .read(shoppingListProvider.notifier)
        .deleteItem(created.id!);
    await settle([aliceContainer, bobContainer]);
    expect(items(aliceContainer), isEmpty);
    expect(items(bobContainer), isEmpty);
  });

  test(
    'personal and shared transitions preserve but never migrate data',
    () async {
      final session = ShoppingTestSession();
      session.store.seed('alice', 'personal', 'Personal rice');
      session.store.seedCollection(
        'pantries/family-abc/shopping_items',
        'abc',
        'ABC milk',
      );
      session.store.seedCollection(
        'pantries/family-xyz/shopping_items',
        'xyz',
        'XYZ bread',
      );
      final container = containerFor(session);
      addTearDown(() async {
        container.dispose();
        await session.changes.close();
      });

      await container.read(shoppingListProvider.future);
      expect(items(container).single.name, 'Personal rice');

      session.changeScope(
        ShoppingScope.shared(actorUid: 'alice', pantryId: 'family-abc'),
      );
      await settle([container]);
      expect(items(container).single.name, 'ABC milk');
      expect(
        session.store.documents,
        contains('users/alice/shopping_items/personal'),
      );

      session.changeScope(
        ShoppingScope.shared(actorUid: 'alice', pantryId: 'family-xyz'),
      );
      await settle([container]);
      expect(items(container).single.name, 'XYZ bread');
      expect(items(container).any((item) => item.name == 'ABC milk'), isFalse);

      session.changeScope(ShoppingScope.personal('alice'));
      await settle([container]);
      expect(items(container).single.name, 'Personal rice');
    },
  );

  test('account switch cancels the previous personal listener', () async {
    final session = ShoppingTestSession();
    session.store.seed('alice', 'alice-item', 'Alice rice');
    session.store.seed('bob', 'bob-item', 'Bob bread');
    final container = containerFor(session);
    addTearDown(() async {
      container.dispose();
      await session.changes.close();
    });

    await container.read(shoppingListProvider.future);
    expect(items(container).single.name, 'Alice rice');
    session.changeUser('bob');
    await settle([container]);
    expect(items(container).single.name, 'Bob bread');
    expect(items(container).any((item) => item.name == 'Alice rice'), isFalse);
  });

  test(
    'concurrent shared low-stock writes create one household item',
    () async {
      final store = FakeShoppingFirestore();
      final alice = ShoppingTestSession(store: store, initialUid: 'alice')
        ..changeScope(
          ShoppingScope.shared(actorUid: 'alice', pantryId: 'family-123'),
        );
      final bob = ShoppingTestSession(store: store, initialUid: 'bob')
        ..changeScope(
          ShoppingScope.shared(actorUid: 'bob', pantryId: 'family-123'),
        );
      final aliceContainer = containerFor(alice);
      final bobContainer = containerFor(bob);
      addTearDown(() async {
        aliceContainer.dispose();
        bobContainer.dispose();
        await alice.changes.close();
        await bob.changes.close();
      });
      await Future.wait([
        aliceContainer.read(shoppingListProvider.future),
        bobContainer.read(shoppingListProvider.future),
      ]);
      final now = DateTime.now();
      final lowStock = PantryItem(
        id: 'pantry-milk',
        firestoreId: 'pantry-milk',
        name: 'Milk',
        category: PantryCategory.dairy,
        location: PantryLocation.refrigerator,
        quantity: 1,
        unit: PantryUnit.bottles,
        expiryDate: DateTime(now.year, now.month, now.day + 2),
      );

      final results = await Future.wait([
        aliceContainer
            .read(shoppingListProvider.notifier)
            .addLowStockSuggestion(lowStock),
        bobContainer
            .read(shoppingListProvider.notifier)
            .addLowStockSuggestion(lowStock),
      ]);
      await settle([aliceContainer, bobContainer]);

      expect(results.whereType<ShoppingItem>(), hasLength(1));
      expect(store.transactionCalls, 2);
      expect(store.addCalls, 1);
      expect(
        store.documents.keys.where(
          (path) => path.startsWith('pantries/family-123/shopping_items/'),
        ),
        hasLength(1),
      );
      expect(items(aliceContainer).single.name, 'Milk');
      expect(items(bobContainer).single.name, 'Milk');

      final expired = lowStock.copyWith(
        firestoreId: 'expired-milk',
        expiryDate: DateTime(now.year, now.month, now.day - 1),
      );
      await expectLater(
        aliceContainer
            .read(shoppingListProvider.notifier)
            .addLowStockSuggestion(expired),
        throwsA(isA<ExpiredLowStockSuggestionException>()),
      );
      expect(store.addCalls, 1);
    },
  );
}
