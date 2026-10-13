import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    container.listen(shoppingListProvider, (_, _) {});
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

  test(
    'duplicates normalize case and whitespace, exclude self, and use only current user',
    () async {
      session.store.seed('alice', 'milk', 'Fresh Milk');
      session.store.seed('bob', 'bread', 'Bread');
      await load();
      final reads = session.store.readCalls;
      for (final name in [
        'fresh milk',
        ' FRESH MILK ',
        ' Fresh   Milk ',
        'Fresh\tMilk',
      ]) {
        expect(notifier().findDuplicate(name)?.id, 'milk');
        await expectLater(
          notifier().addItem(ShoppingItem(name: name, quantity: 2)),
          throwsA(isA<ShoppingDuplicateException>()),
        );
      }
      expect(notifier().findDuplicate('Fresh'), isNull);
      expect(notifier().findDuplicate('Bread'), isNull);
      expect(notifier().findDuplicate('Fresh Milk', excludeId: 'milk'), isNull);
      expect(items().single.name, 'Fresh Milk');
      expect(session.store.readCalls, reads);
      expect(session.store.addCalls, 0);
      expect(session.store.updateCalls, 0);
    },
  );

  test(
    'Increase Quantity persists to the same document without changing capitalization',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      session.store.documents.values.single['quantity'] = 4;
      await load();
      final saved = await notifier().addItem(
        const ShoppingItem(name: ' MILK ', quantity: 2),
        duplicateAction: ShoppingDuplicateAction.increaseQuantity,
        confirmedDuplicate: items().single,
      );
      expect(saved.id, 'milk');
      expect(saved.quantity, 6);
      expect(saved.name, 'Milk');
      expect(session.store.documents.length, 1);
      expect(session.store.addCalls, 0);
      await notifier().reload();
      expect(items().single.quantity, 6);
    },
  );

  test(
    'explicit Add Anyway creates a new document with the preferred display name',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      await load();
      final saved = await notifier().addItem(
        const ShoppingItem(name: ' miLK ', quantity: 2),
        duplicateAction: ShoppingDuplicateAction.addAnyway,
        confirmedDuplicate: items().single,
      );
      expect(saved.id, isNot('milk'));
      expect(saved.name, 'miLK');
      expect(items().length, 2);
      expect(session.store.addCalls, 1);
      expect(session.store.updateCalls, 0);
    },
  );

  test(
    'Bought duplicate moves to To Buy with requested quantity, not combined',
    () async {
      session.store.seed('alice', 'milk', 'Milk', purchased: true);
      session.store.documents.values.single['quantity'] = 90;
      await load();
      await notifier().addItem(
        const ShoppingItem(name: 'milk', quantity: 3),
        duplicateAction: ShoppingDuplicateAction.moveToBuy,
        confirmedDuplicate: items().single,
      );
      await notifier().reload();
      expect(items().single.id, 'milk');
      expect(items().single.quantity, 3);
      expect(items().single.isPurchased, isFalse);
      expect(session.store.addCalls, 0);
    },
  );

  test(
    'combined quantity over 100 is rejected, not clamped; exactly 100 works',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      session.store.documents.values.single['quantity'] = 99;
      await load();
      await expectLater(
        notifier().addItem(
          const ShoppingItem(name: 'milk', quantity: 2),
          duplicateAction: ShoppingDuplicateAction.increaseQuantity,
          confirmedDuplicate: items().single,
        ),
        throwsA(isA<ShoppingQuantityLimitException>()),
      );
      expect(items().single.quantity, 99);
      expect(session.store.updateCalls, 0);
      expect(session.store.addCalls, 0);
      await notifier().addItem(
        const ShoppingItem(name: 'milk', quantity: 1),
        duplicateAction: ShoppingDuplicateAction.increaseQuantity,
        confirmedDuplicate: items().single,
      );
      expect(items().single.quantity, 100);
    },
  );

  test(
    'stale duplicate confirmation is checked again before any update',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      await load();
      final old = items().single;
      await notifier().updateItem('milk', old.copyWith(quantity: 5));
      await expectLater(
        notifier().addItem(
          const ShoppingItem(name: 'milk', quantity: 2),
          duplicateAction: ShoppingDuplicateAction.increaseQuantity,
          confirmedDuplicate: old,
        ),
        throwsA(
          isA<ShoppingDuplicateException>().having(
            (e) => e.existing.quantity,
            'new quantity',
            5,
          ),
        ),
      );
      expect(items().single.quantity, 5);
      expect(session.store.updateCalls, 1);
    },
  );

  test('intentional duplicates choose To Buy first then stable ID', () async {
    session.store.seed('alice', 'a', 'Milk', purchased: true);
    session.store.seed('alice', 'c', 'milk');
    session.store.seed('alice', 'b', 'MILK');
    await load();
    expect(notifier().findDuplicate('milk')?.id, 'b');
  });

  test(
    'edit ignores self, preserves Bought, and warns for another matching name',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      session.store.seed('alice', 'eggs', 'Eggs', purchased: true);
      await load();
      await notifier().saveEditedItem(
        const ShoppingItem(id: 'eggs', name: ' eggs ', quantity: 3),
      );
      expect(items().last.isPurchased, isTrue);
      const renamed = ShoppingItem(id: 'eggs', name: ' MILK ', quantity: 5);
      await expectLater(
        notifier().saveEditedItem(renamed),
        throwsA(isA<ShoppingDuplicateException>()),
      );
      expect(items().last.name, 'eggs');
      await notifier().saveEditedItem(
        renamed,
        confirmedDuplicate: notifier().findDuplicate('Milk', excludeId: 'eggs'),
      );
      await notifier().reload();
      expect(items().last.id, 'eggs');
      expect(items().last.name, 'MILK');
      expect(items().last.isPurchased, isTrue);
      expect(items().first.quantity, 2);
      expect(session.store.documents.length, 2);
      expect(session.store.addCalls, 0);
    },
  );

  test(
    'failed duplicate increase rolls back and blocks simultaneous confirmation',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      await load();
      final original = items().single;
      final gate = Completer<void>();
      session.store.updateGate = gate.future;
      session.store.updateError = StateError('Test failure');
      final saving = notifier().addItem(
        const ShoppingItem(name: 'milk', quantity: 2),
        duplicateAction: ShoppingDuplicateAction.increaseQuantity,
        confirmedDuplicate: original,
      );
      final result = expectLater(saving, throwsStateError);
      await expectLater(
        notifier().addItem(
          const ShoppingItem(name: 'milk', quantity: 2),
          duplicateAction: ShoppingDuplicateAction.increaseQuantity,
          confirmedDuplicate: original,
        ),
        throwsStateError,
      );
      gate.complete();
      await result;
      expect(items().single.quantity, 2);
      expect(session.store.updateCalls, 1);
      expect(session.store.addCalls, 0);
    },
  );

  test(
    'failed refresh retains valid data and allows subsequent writes',
    () async {
      session.store.seed('alice', 'milk', 'Milk');
      await load();
      session.store.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(notifier().reload(), throwsA(isA<FirebaseException>()));
      expect(items().single.name, 'Milk');
      expect(container.read(shoppingListProvider).hasError, isFalse);
      await notifier().togglePurchased('milk', true);
      expect(items().single.isPurchased, isTrue);
    },
  );

  test(
    'pending refresh cannot restore old data after account switch',
    () async {
      session.store.seed('alice', 'milk', 'Alice milk');
      session.store.seed('bob', 'milk', 'Bob milk');
      await load();
      final gate = Completer<void>();
      session.store.readGate = gate.future;
      final refreshing = expectLater(notifier().reload(), throwsStateError);
      session.store.readGate = null;
      session.changeUser('bob');
      await container.pump();
      await load();
      expect(items().single.name, 'Bob milk');
      gate.complete();
      await refreshing;
      expect(items().single.name, 'Bob milk');
    },
  );
}
