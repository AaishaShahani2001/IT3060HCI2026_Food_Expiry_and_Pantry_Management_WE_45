import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/automatic_waste_candidate.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_scope.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_summary.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';

import 'support/fake_waste_firestore.dart';
import 'support/waste_test_session.dart';

ProviderContainer _container(WasteTestSession session) {
  final container = ProviderContainer(
    overrides: [
      foodWasteRepositoryProvider.overrideWithValue(session.repository),
      wasteAuthUidProvider.overrideWith((ref) => session.auth()),
    ],
  );
  container.listen(foodWasteProvider, (_, _) {});
  return container;
}

Future<List<FoodWasteRecord>> _settle(ProviderContainer container) async {
  await pumpEventQueue(times: 3);
  return container.read(foodWasteProvider.future);
}

AutomaticWasteCandidate _automatic(WasteScope scope) {
  final expiry = DateTime(2026, 9, 15);
  return AutomaticWasteCandidate(
    scope: scope,
    record: FoodWasteRecord(
      id: automaticWasteEventId('milk', expiry),
      itemName: 'Milk',
      quantity: 2,
      unit: 'bottle',
      reason: 'Expired',
      estimatedValue: 800,
      wastedAt: DateTime(2026, 9, 16),
      source: automaticExpiryWasteSource,
      sourcePantryItemId: 'milk',
      sourceExpiryDate: expiry,
    ),
  );
}

void main() {
  test('scope selects personal and household collection paths', () {
    expect(
      WasteScope.personal(actorUid: 'alice').collectionPath,
      'users/alice/waste_records',
    );
    expect(
      WasteScope.shared(
        actorUid: 'alice',
        pantryId: 'family-one',
      ).collectionPath,
      'pantries/family-one/waste_records',
    );
    expect(
      WasteScope.shared(actorUid: 'alice', pantryId: 'family-one'),
      isNot(WasteScope.shared(actorUid: 'bob', pantryId: 'family-one')),
    );
  });

  test('household members receive realtime create edit and delete', () async {
    final store = FakeWasteFirestore();
    final alice = WasteTestSession(store: store, initialUid: 'alice');
    final bob = WasteTestSession(store: store, initialUid: 'bob');
    final aliceScope = WasteScope.shared(
      actorUid: 'alice',
      pantryId: 'family-one',
    );
    final bobScope = WasteScope.shared(actorUid: 'bob', pantryId: 'family-one');
    alice.changeScope(aliceScope);
    bob.changeScope(bobScope);
    final aliceContainer = _container(alice);
    final bobContainer = _container(bob);
    addTearDown(() async {
      aliceContainer.dispose();
      bobContainer.dispose();
      await alice.dispose();
      await bob.dispose();
    });

    expect(await _settle(aliceContainer), isEmpty);
    expect(await _settle(bobContainer), isEmpty);
    expect(store.activeListeners('pantries/family-one/waste_records'), 2);

    final created = await aliceContainer
        .read(foodWasteProvider.notifier)
        .save(draft(name: 'Shared milk'), expectedScope: aliceScope);
    await pumpEventQueue();
    expect(
      bobContainer.read(foodWasteProvider).requireValue.single.itemName,
      'Shared milk',
    );
    expect(created.recordedByUid, 'alice');

    final bobRecord = bobContainer.read(foodWasteProvider).requireValue.single;
    await bobContainer
        .read(foodWasteProvider.notifier)
        .save(
          bobRecord.copyWith(itemName: 'Edited together'),
          expectedScope: bobScope,
        );
    await pumpEventQueue();
    final edited = aliceContainer.read(foodWasteProvider).requireValue.single;
    expect(edited.itemName, 'Edited together');
    expect(edited.recordedByUid, 'alice');

    await bobContainer
        .read(foodWasteProvider.notifier)
        .delete(edited.id!, expectedScope: bobScope);
    await pumpEventQueue();
    expect(aliceContainer.read(foodWasteProvider).requireValue, isEmpty);
    expect(store.documents, isEmpty);
  });

  test('shared realtime records update dashboard totals', () async {
    final store = FakeWasteFirestore();
    final alice = WasteTestSession(store: store, initialUid: 'alice');
    final bob = WasteTestSession(store: store, initialUid: 'bob');
    final aliceScope = WasteScope.shared(
      actorUid: 'alice',
      pantryId: 'family-one',
    );
    final bobScope = WasteScope.shared(actorUid: 'bob', pantryId: 'family-one');
    alice.changeScope(aliceScope);
    bob.changeScope(bobScope);
    final aliceContainer = _container(alice);
    final bobContainer = _container(bob);
    addTearDown(() async {
      aliceContainer.dispose();
      bobContainer.dispose();
      await alice.dispose();
      await bob.dispose();
    });
    await _settle(aliceContainer);
    await _settle(bobContainer);

    await aliceContainer
        .read(foodWasteProvider.notifier)
        .save(draft(quantity: 2, value: 580), expectedScope: aliceScope);
    await pumpEventQueue();
    final summary = WasteSummary(
      bobContainer.read(foodWasteProvider).requireValue,
      WastePeriod.today,
      wasteTestNow,
    );
    expect(summary.count, 1);
    expect(summary.quantitiesByUnit, {'pcs': 2});
    expect(summary.estimatedValue, 580);
  });

  test(
    'personal family and pantry transitions never migrate or flash records',
    () async {
      final session = WasteTestSession(initialUid: 'alice');
      final personal = WasteScope.personal(actorUid: 'alice');
      final familyA = WasteScope.shared(
        actorUid: 'alice',
        pantryId: 'family-a',
      );
      final familyB = WasteScope.shared(
        actorUid: 'alice',
        pantryId: 'family-b',
      );
      session.seedScope(personal, 'personal', draft(name: 'Personal'));
      session.seedScope(familyA, 'a', draft(name: 'Family A'));
      session.seedScope(familyB, 'b', draft(name: 'Family B'));
      final container = _container(session);
      addTearDown(() async {
        container.dispose();
        await session.dispose();
      });

      expect((await _settle(container)).single.itemName, 'Personal');
      session.changeScope(familyA);
      await pumpEventQueue();
      expect(
        container
                .read(foodWasteProvider)
                .asData
                ?.value
                .any((record) => record.itemName == 'Personal') ??
            false,
        isFalse,
      );
      expect((await _settle(container)).single.itemName, 'Family A');
      expect(session.store.activeListeners(personal.collectionPath), 0);

      session.changeScope(familyB);
      expect((await _settle(container)).single.itemName, 'Family B');
      session.store.notifyDocument('${familyA.collectionPath}/a');
      await pumpEventQueue();
      expect(
        container.read(foodWasteProvider).requireValue.single.itemName,
        'Family B',
      );
      expect(session.store.activeListeners(familyA.collectionPath), 0);

      session.changeScope(personal);
      expect((await _settle(container)).single.itemName, 'Personal');
      expect(session.store.documents, hasLength(3));
    },
  );

  test('account switch and logout cancel prior scoped listeners', () async {
    final session = WasteTestSession(initialUid: 'alice');
    final alice = WasteScope.personal(actorUid: 'alice');
    final bob = WasteScope.personal(actorUid: 'bob');
    session.seedScope(alice, 'a', draft(name: 'Alice'));
    session.seedScope(bob, 'b', draft(name: 'Bob'));
    final container = _container(session);
    addTearDown(() async {
      container.dispose();
      await session.dispose();
    });

    expect((await _settle(container)).single.itemName, 'Alice');
    session.changeUser('bob');
    expect((await _settle(container)).single.itemName, 'Bob');
    expect(session.store.activeListeners(alice.collectionPath), 0);
    session.changeUser(null);
    expect(await _settle(container), isEmpty);
    expect(session.store.activeListeners(bob.collectionPath), 0);
  });

  test(
    'unavailable shared scope never falls back to personal records',
    () async {
      final session = WasteTestSession(initialUid: 'alice');
      session.seed('alice', 'private', draft(name: 'Private'));
      final container = _container(session);
      addTearDown(() async {
        container.dispose();
        await session.dispose();
      });
      expect((await _settle(container)).single.itemName, 'Private');

      session.failScope('alice', StateError('membership unavailable'));
      await pumpEventQueue(times: 3);
      expect(container.read(wasteScopeProvider).hasError, isTrue);
      expect(container.read(foodWasteProvider).asData, isNull);
    },
  );

  test(
    'two members create one deterministic household automatic event',
    () async {
      final store = FakeWasteFirestore();
      final alice = WasteTestSession(store: store, initialUid: 'alice');
      final bob = WasteTestSession(store: store, initialUid: 'bob');
      final aliceScope = WasteScope.shared(
        actorUid: 'alice',
        pantryId: 'family-one',
      );
      final bobScope = WasteScope.shared(
        actorUid: 'bob',
        pantryId: 'family-one',
      );
      alice.changeScope(aliceScope);
      bob.changeScope(bobScope);
      await alice.repository
          .watchScope('alice')
          .where((scope) => scope != null)
          .first;
      await bob.repository
          .watchScope('bob')
          .where((scope) => scope != null)
          .first;
      addTearDown(() async {
        await alice.dispose();
        await bob.dispose();
      });

      final results = await Future.wait([
        alice.repository.reconcileAutomatic(aliceScope, [
          _automatic(aliceScope),
        ]),
        bob.repository.reconcileAutomatic(bobScope, [_automatic(bobScope)]),
      ]);
      expect(results.where((created) => created), hasLength(1));
      expect(store.documents, hasLength(1));
      final record = FoodWasteRecord.fromMap(
        store.documents.keys.single.split('/').last,
        store.documents.values.single,
      );
      expect(record.recordedByUid, anyOf('alice', 'bob'));
    },
  );

  test(
    'household Not Wasted suppresses every member and is not recreated',
    () async {
      final store = FakeWasteFirestore();
      final alice = WasteTestSession(store: store, initialUid: 'alice');
      final bob = WasteTestSession(store: store, initialUid: 'bob');
      final aliceScope = WasteScope.shared(
        actorUid: 'alice',
        pantryId: 'family-one',
      );
      final bobScope = WasteScope.shared(
        actorUid: 'bob',
        pantryId: 'family-one',
      );
      alice.changeScope(aliceScope);
      bob.changeScope(bobScope);
      final aliceContainer = _container(alice);
      final bobContainer = _container(bob);
      addTearDown(() async {
        aliceContainer.dispose();
        bobContainer.dispose();
        await alice.dispose();
        await bob.dispose();
      });
      await _settle(aliceContainer);
      await _settle(bobContainer);
      await aliceContainer.read(foodWasteProvider.notifier).reconcileAutomatic([
        _automatic(aliceScope),
      ]);
      await pumpEventQueue();
      final sharedRecord = bobContainer
          .read(foodWasteProvider)
          .requireValue
          .single;

      await bobContainer
          .read(foodWasteProvider.notifier)
          .markNotWasted(sharedRecord, expectedScope: bobScope);
      await pumpEventQueue();
      expect(aliceContainer.read(foodWasteProvider).requireValue, isEmpty);
      expect(bobContainer.read(foodWasteProvider).requireValue, isEmpty);
      expect(store.documents.values.single['notWasted'], isTrue);
      expect(
        await alice.repository.reconcileAutomatic(aliceScope, [
          _automatic(aliceScope),
        ]),
        isFalse,
      );
      expect(store.documents, hasLength(1));
    },
  );
}
