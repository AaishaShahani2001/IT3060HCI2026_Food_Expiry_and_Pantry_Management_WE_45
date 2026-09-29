import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_firestore_service.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/low_stock_shopping_sync_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/widgets/low_stock_shopping_sync_host.dart';

import 'support/fake_firestore.dart';

PantryItem stock(
  double quantity, {
  String id = 'pantry-milk',
  String name = 'Milk',
  PantryUnit unit = PantryUnit.bottles,
  DateTime? expiry,
  bool connected = true,
}) => PantryItem(
  id: id,
  firestoreId: connected ? id : null,
  name: name,
  category: PantryCategory.dairy,
  location: PantryLocation.refrigerator,
  quantity: quantity,
  unit: unit,
  expiryDate: expiry,
);

class _Pantry extends Fake implements PantryFirestoreService {
  final items = <String, List<PantryItem>>{};
  final listeners = <String, Set<MultiStreamController<List<PantryItem>>>>{};
  int subscriptions = 0;
  void emit(List<PantryItem> values, {String uid = 'alice'}) {
    items[uid] = values;
    for (final listener in listeners[uid] ?? {}) {
      listener.add(List.of(values));
    }
  }

  void fail() {
    for (final listener in listeners['alice'] ?? {}) {
      listener.addError(StateError('private backend detail'));
    }
  }

  @override
  Stream<List<PantryItem>> watchPantryItems({required String userId}) =>
      Stream.multi((controller) {
        subscriptions++;
        (listeners[userId] ??= {}).add(controller);
        controller.add(List.of(items[userId] ?? []));
        controller.onCancel = () => listeners[userId]?.remove(controller);
      });
}

void main() {
  late ShoppingTestSession session;
  late _Pantry pantry;
  late ProviderContainer container;
  late List<LowStockSyncFeedback> notices;
  setUp(() {
    session = ShoppingTestSession();
    pantry = _Pantry();
    notices = [];
    container = ProviderContainer(
      overrides: [
        shoppingListRepositoryProvider.overrideWithValue(session.repository),
        shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
        pantryFirestoreServiceProvider.overrideWithValue(pantry),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await session.changes.close();
  });
  Future<void> settle() async {
    // Flush finite stream / provider / Firestore-fake continuations, no timers
    // or network retries are used by production sync.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> start(List<PantryItem> items) async {
    pantry.emit(items);
    container.listen(lowStockShoppingSyncProvider, (_, next) {
      final notice = next.asData?.value;
      if (notice != null && !notices.contains(notice)) notices.add(notice);
    });
    await settle();
  }

  ShoppingListNotifier notifier() =>
      container.read(shoppingListProvider.notifier);
  List<ShoppingItem> items() =>
      container.read(shoppingListProvider).requireValue;
  void seedLinked({
    bool bought = true,
    String name = 'Milk',
    int quantity = 7,
  }) {
    session.store.documents['users/alice/shopping_items/saved'] = ShoppingItem(
      name: name,
      quantity: quantity,
      isPurchased: bought,
      source: 'low_stock',
      sourcePantryItemId: 'pantry-milk',
    ).toMap();
  }

  test(
    'normal, expiry alone, expiring soon and unsaved items are excluded',
    () async {
      await start([
        stock(4),
        stock(5, id: 'expired', expiry: DateTime(2020)),
        stock(
          5,
          id: 'soon',
          expiry: DateTime.now().add(const Duration(days: 1)),
        ),
        stock(0, id: 'unsaved', connected: false),
        stock(double.nan, id: 'invalid'),
      ]);
      expect(session.store.addCalls, 0);
      expect(notices, isEmpty);
    },
  );
  for (final quantity in [1.0, 0.0]) {
    test(
      '$quantity stock auto-adds once with UID, metadata and restock quantity 1',
      () async {
        final original = stock(quantity);
        await start([original]);
        expect(items().single.quantity, 1);
        expect(items().single.isPurchased, isFalse);
        expect(items().single.source, 'low_stock');
        expect(items().single.sourcePantryItemId, original.firestoreId);
        expect(
          session.store.documents.keys.single,
          startsWith('users/alice/shopping_items/'),
        );
        expect(
          notices.single.message,
          contains(quantity == 0 ? 'out of stock' : 'stock is low'),
        );
        pantry.emit([original]);
        pantry.emit([original]);
        container.read(lowStockShoppingSyncProvider);
        await settle();
        expect(session.store.addCalls, 1);
        expect(notices.length, 1);
        expect(pantry.items['alice']!.single, same(original));
      },
    );
  }
  test('uses Pantry unit-specific threshold, not a second threshold', () async {
    await start([
      stock(100, unit: PantryUnit.g),
      stock(101, id: 'normal', unit: PantryUnit.ml),
    ]);
    expect(items().length, 1);
    expect(items().single.quantity, 1);
  });
  for (final name in ['Milk', 'milk', ' MILK ', '  Fresh\t  Milk ']) {
    test(
      'manual To Buy preserved verbatim for normalized name $name',
      () async {
        final savedName = name.contains('Fresh') ? 'Fresh Milk' : 'Milk';
        session.store.seed('alice', 'manual', savedName);
        final original = Map.of(session.store.documents.values.single);
        await start([stock(0, name: name)]);
        expect(session.store.addCalls, 0);
        expect(session.store.updateCalls, 0);
        expect(session.store.documents.values.single, original);
        expect(notices, isEmpty);
      },
    );
  }
  test('source ID matches even when user renamed the Shopping item', () async {
    seedLinked(bought: false, name: 'My organic milk');
    await start([stock(0)]);
    expect(items().single.name, 'My organic milk');
    expect(items().single.quantity, 7);
    expect(session.store.addCalls, 0);
  });
  test('initial startup respects linked Bought and manual Bought', () async {
    seedLinked();
    session.store.seed('alice', 'manual', 'Bread', purchased: true);
    await start([stock(0), stock(0, id: 'bread', name: 'Bread')]);
    expect(items().every((item) => item.isPurchased), isTrue);
    expect(session.store.updateCalls, 0);
    expect(session.store.addCalls, 0);
    expect(notices, isEmpty);
  });
  test(
    'normal to low triggers once; low to out stays in the same episode',
    () async {
      await start([stock(5)]);
      pantry.emit([stock(1)]);
      await settle();
      pantry.emit([stock(0)]);
      await settle();
      expect(session.store.addCalls, 1);
      expect(notices.length, 1);
    },
  );
  test('normal to out triggers', () async {
    await start([stock(5)]);
    pantry.emit([stock(0)]);
    await settle();
    expect(session.store.addCalls, 1);
  });
  test('delete is respected until recovery then a new low cycle', () async {
    await start([stock(1)]);
    await notifier().deleteItem(items().single.id!);
    pantry.emit([stock(1)]);
    await notifier().reload();
    await settle();
    expect(items(), isEmpty);
    expect(session.store.addCalls, 1);
    pantry.emit([stock(4)]);
    await settle();
    pantry.emit([stock(0)]);
    await settle();
    expect(session.store.addCalls, 2);
    expect(items().length, 1);
  });
  test(
    'Bought stays Bought until recovery and future genuine low transition',
    () async {
      await start([stock(1)]);
      final id = items().single.id!;
      await notifier().saveEditedItem(
        ShoppingItem(id: id, name: 'Organic Milk', quantity: 8),
      );
      await notifier().togglePurchased(id, true);
      pantry.emit([stock(0)]);
      await settle();
      expect(items().single.isPurchased, isTrue);
      pantry.emit([stock(5)]);
      await settle();
      expect(items().single.isPurchased, isTrue);
      pantry.emit([stock(1)]);
      await settle();
      expect(items().single.id, id);
      expect(items().single.name, 'Organic Milk');
      expect(items().single.quantity, 8);
      expect(items().single.isPurchased, isFalse);
      expect(items().single.sourcePantryItemId, 'pantry-milk');
      expect(session.store.addCalls, 1);
      expect(notices.last.message, contains('moved back to To Buy'));
      await notifier().reload();
      expect(items().single.source, 'low_stock');
    },
  );
  test('recovery never deletes or changes an existing To Buy item', () async {
    await start([stock(1)]);
    final original = Map.of(session.store.documents.values.single);
    pantry.emit([stock(9)]);
    await settle();
    expect(session.store.documents.values.single, original);
    expect(session.store.commitCalls, 0);
  });
  test('manual Bought is not changed by a new low cycle', () async {
    session.store.seed('alice', 'manual', 'Milk', purchased: true);
    await start([stock(4)]);
    pantry.emit([stock(1)]);
    await settle();
    expect(items().single.isPurchased, isTrue);
    expect(session.store.updateCalls, 0);
    expect(session.store.addCalls, 0);
  });
  test(
    'active name match prevents reactivating another linked Bought duplicate',
    () async {
      seedLinked();
      session.store.seed('alice', 'manual', 'Milk');
      await start([stock(5)]);
      pantry.emit([stock(1)]);
      await settle();
      expect(session.store.updateCalls, 0);
      expect(session.store.addCalls, 0);
    },
  );
  test(
    'same-named Pantry documents do not create two Shopping items',
    () async {
      await start([stock(0), stock(0, id: 'second', name: ' MILK ')]);
      expect(session.store.addCalls, 1);
    },
  );
  test('multiple changes are summarized in one compact notice', () async {
    await start([stock(0), stock(1, id: 'eggs', name: 'Eggs')]);
    expect(items().length, 2);
    expect(notices.length, 1);
    expect(notices.single.message, contains('2 low-stock items'));
  });
  test('write failure is friendly, no retry loop, Pantry untouched', () async {
    session.store.addError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final original = stock(1);
    await start([original]);
    expect(notices.single.message, "Couldn't add Milk to Shopping List.");
    pantry.emit([original]);
    await settle();
    expect(session.store.addCalls, 1);
    expect(session.store.documents, isEmpty);
    expect(pantry.items['alice']!.single, same(original));
  });
  test(
    'failed reactivation retains Bought and is not retried on low updates',
    () async {
      seedLinked();
      session.store.updateError = StateError('private');
      await start([stock(5)]);
      pantry.emit([stock(1)]);
      await settle();
      pantry.emit([stock(0)]);
      await settle();
      expect(items().single.isPurchased, isTrue);
      expect(session.store.updateCalls, 1);
      expect(notices.single.message, isNot(contains('private')));
    },
  );
  test('Pantry stream errors are reported once per outage', () async {
    await start([]);
    pantry.fail();
    pantry.fail();
    await settle();
    expect(notices.length, 1);
    expect(notices.single.message, contains("Couldn't check"));
    expect(session.store.addCalls, 0);
  });
  test('deleted or recovered Pantry items cancel a queued add', () async {
    final gate = Completer<void>();
    session.store.readGate = gate.future;
    await start([stock(1)]);
    pantry.emit([]);
    await settle();
    gate.complete();
    await settle();
    expect(session.store.addCalls, 0);
  });
  test('recovery while waiting for Shopping read cancels an add', () async {
    final gate = Completer<void>();
    session.store.readGate = gate.future;
    await start([stock(1)]);
    pantry.emit([stock(4)]);
    await settle();
    gate.complete();
    await settle();
    expect(session.store.addCalls, 0);
  });
  test(
    'auth switch removes old listeners and initializes only the new user',
    () async {
      pantry.emit([stock(0, name: 'Bob Bread')], uid: 'bob');
      await start([stock(0)]);
      session.changeUser('bob');
      await settle();
      expect(pantry.listeners['alice'], isEmpty);
      expect(items().single.name, 'Bob Bread');
      expect(
        session
            .store
            .documents['users/bob/shopping_items/${items().single.id}']!['name'],
        'Bob Bread',
      );
      pantry.emit([stock(5)]);
      pantry.emit([stock(0, name: 'Alice only')]);
      await settle();
      expect(items().single.name, 'Bob Bread');
      session.changeUser(null);
      await settle();
      expect(pantry.listeners['bob'], isEmpty);
      expect(items(), isEmpty);
    },
  );
  test(
    'account switch during read never queues Alice data into Bob writes',
    () async {
      final gate = Completer<void>();
      session.store.readGate = gate.future;
      await start([stock(1)]);
      session.changeUser('bob');
      await settle();
      gate.complete();
      await settle();
      expect(session.store.documents, isEmpty);
      expect(notices, isEmpty);
    },
  );
  test(
    'late in-flight write stays in old UID path and cannot update new UI',
    () async {
      final gate = Completer<void>();
      session.store.addGate = gate.future;
      await start([stock(1)]);
      expect(session.store.addCalls, 1);
      session.changeUser('bob');
      await settle();
      gate.complete();
      await settle();
      expect(items(), isEmpty);
      expect(session.store.documents.keys.single, startsWith('users/alice/'));
      expect(notices, isEmpty);
    },
  );
  test(
    'background sync waits for manual add then rechecks duplicates',
    () async {
      await start([stock(5)]);
      final gate = Completer<void>();
      session.store.addGate = gate.future;
      final save = notifier().addItem(
        const ShoppingItem(name: 'Milk', quantity: 9),
      );
      pantry.emit([stock(1)]);
      await settle();
      expect(session.store.addCalls, 1);
      gate.complete();
      await save;
      await settle();
      expect(items().single.quantity, 9);
      expect(items().single.source, isNull);
      expect(session.store.addCalls, 1);
      expect(notices, isEmpty);
    },
  );
  test(
    'fresh storage read sees externally added manual Shopping item',
    () async {
      await start([stock(5)]);
      session.store.seed('alice', 'external', 'Milk');
      pantry.emit([stock(1)]);
      await settle();
      expect(items().single.id, 'external');
      expect(session.store.addCalls, 0);
    },
  );
  test(
    'legacy documents stay valid and source fields survive round-trip/copy',
    () {
      final legacy = ShoppingItem.fromMap('old', {
        'name': 'Milk',
        'quantity': 1,
      });
      expect(legacy.source, isNull);
      expect(
        legacy.toMap().keys,
        unorderedEquals(['name', 'quantity', 'isPurchased']),
      );
      final linked = legacy.copyWith(
        source: 'low_stock',
        sourcePantryItemId: 'pantry',
      );
      final decoded = ShoppingItem.fromMap(
        'old',
        linked.toMap(),
      ).copyWith(quantity: 4);
      expect(decoded.source, 'low_stock');
      expect(decoded.sourcePantryItemId, 'pantry');
    },
  );
  test('new app scope while still low does not reactivate Bought', () async {
    await start([stock(1)]);
    await notifier().togglePurchased(items().single.id!, true);
    container.invalidate(lowStockShoppingSyncProvider);
    await settle();
    expect(items().single.isPurchased, isTrue);
    expect(session.store.updateCalls, 1);
  });
  testWidgets(
    'root host syncs outside Shopping route, without duplicate listeners on rebuild',
    (tester) async {
      pantry.emit([stock(1)]);
      Widget app() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => LowStockShoppingSyncHost(child: child!),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(
        find.text('Milk added to Shopping List — stock is low.'),
        findsOneWidget,
      );
      expect(pantry.subscriptions, 1);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(pantry.subscriptions, 1);
      expect(session.store.addCalls, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      pantry.emit([stock(1), stock(0, id: 'eggs', name: 'Eggs')]);
      await tester.pumpAndSettle();
      expect(
        find.text('Eggs added to Shopping List — out of stock.'),
        findsOneWidget,
      );
      session.changeUser(null);
      await tester.pumpAndSettle();
      expect(
        find.text('Milk added to Shopping List — stock is low.'),
        findsNothing,
      );
      expect(
        find.text('Eggs added to Shopping List — out of stock.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
