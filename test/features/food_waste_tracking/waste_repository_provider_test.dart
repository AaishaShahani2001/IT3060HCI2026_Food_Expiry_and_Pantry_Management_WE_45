import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'support/waste_test_session.dart';

void main() {
  late WasteTestSession session;
  late ProviderContainer container;
  setUp(() {
    session = WasteTestSession();
    container = ProviderContainer(
      overrides: [
        foodWasteRepositoryProvider.overrideWithValue(session.repository),
        wasteAuthUidProvider.overrideWith((ref) => session.auth()),
      ],
    );
    container.listen(foodWasteProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await session.changes.close();
  });
  Future<List<FoodWasteRecord>> load() =>
      container.read(foodWasteProvider.future);
  FoodWasteNotifier notifier() => container.read(foodWasteProvider.notifier);
  List<FoodWasteRecord> records() =>
      container.read(foodWasteProvider).requireValue;

  Future<WasteDuplicateWarning> warningFor(FoodWasteRecord record) async {
    try {
      await notifier().save(record);
      fail('Expected duplicate warning before any write');
    } on WasteDuplicateWarning catch (warning) {
      return warning;
    }
  }

  test(
    'duplicate uses normalized name, local date, reason and unit quantity',
    () async {
      session.seed('alice', 'id', draft(name: 'Homemade Rice'));
      await load();
      await warningFor(
        draft(name: '  homemade   RICE ', date: DateTime(2026, 9, 16, 23)),
      );
      expect(session.store.addCalls, 0);
      await notifier().save(draft(name: 'Homemade Rice', quantity: 3));
      await notifier().save(draft(name: 'Homemade Rice', unit: 'kg'));
      await notifier().save(
        draft(name: 'Homemade Rice').copyWith(reason: 'Spoiled'),
      );
      await notifier().save(
        draft(name: 'Homemade Rice', date: DateTime(2026, 9, 15)),
      );
      expect(session.store.addCalls, 4);
    },
  );
  test(
    'Save Anyway creates once; edit excludes itself but warns for another record',
    () async {
      session.seed('alice', 'id', draft());
      await load();
      await notifier().save(records().single.copyWith(estimatedValue: 150));
      expect(session.store.updateCalls, 1);
      final candidate = draft();
      final warning = await warningFor(candidate);
      await notifier().save(candidate, confirmedDuplicate: warning);
      expect(records().length, 2);
      expect(session.store.addCalls, 1);
      // The new matching record invalidates the old confirmation.
      await expectLater(
        notifier().save(candidate, confirmedDuplicate: warning),
        throwsA(isA<WasteDuplicateWarning>()),
      );
      await warningFor(records().first.copyWith(estimatedValue: 200));
      expect(session.store.updateCalls, 1);
    },
  );
  test(
    'duplicate confirmation cannot be reused for changed draft or refreshed data',
    () async {
      session.seed('alice', 'id', draft());
      await load();
      final candidate = draft();
      final warning = await warningFor(candidate);
      await expectLater(
        notifier().save(
          candidate.copyWith(estimatedValue: 999),
          confirmedDuplicate: warning,
        ),
        throwsA(isA<WasteDuplicateWarning>()),
      );
      await notifier().reload();
      await expectLater(
        notifier().save(candidate, confirmedDuplicate: warning),
        throwsA(isA<WasteDuplicateWarning>()),
      );
      expect(session.store.addCalls, 0);
    },
  );
  test(
    'duplicate detection and confirmation are isolated to authenticated user',
    () async {
      session.seed('bob', 'id', draft());
      await load();
      await notifier().save(
        draft(),
      ); // Bob's matching record does not block Alice.
      final candidate = draft();
      final warning = await warningFor(candidate);
      session.changeUser('bob');
      await Future<void>.delayed(Duration.zero);
      await load();
      await expectLater(
        notifier().save(candidate, confirmedDuplicate: warning),
        throwsA(isA<WasteDuplicateWarning>()),
      );
      expect(session.store.addCalls, 1);
    },
  );

  test(
    'create/read uses generated documents in current user waste_records',
    () async {
      session.seed('bob', 'private', draft(name: 'Private'));
      await load();
      final saved = await notifier().save(draft(name: ' Apples '));
      expect(saved.id, isNotEmpty);
      expect(saved.itemName, 'Apples');
      expect(
        session.store.documents['users/alice/waste_records/${saved.id}'],
        saved.toMap(),
      );
      await notifier().reload();
      expect(records().single.itemName, 'Apples');
      expect(
        session.store.documents.containsKey('users/bob/waste_records/private'),
        isTrue,
      );
    },
  );
  test(
    'update keeps ID, writes all edited values and survives reload',
    () async {
      session.seed('alice', 'id', draft());
      await load();
      await notifier().save(
        records().single.copyWith(
          itemName: 'Rice',
          quantity: 0.5,
          unit: 'kg',
          reason: 'Not Used',
          estimatedValue: 15,
          wastedAt: DateTime(2026, 9, 1),
        ),
      );
      await notifier().reload();
      expect(records().single.id, 'id');
      expect(records().single.itemName, 'Rice');
      expect(records().single.quantity, 0.5);
      expect(records().single.reason, 'Not Used');
      expect(session.store.addCalls, 0);
      expect(session.store.updateCalls, 1);
    },
  );
  test(
    'delete persists after reload and preserves other user and parent document',
    () async {
      session.seed('alice', 'id', draft());
      session.seed('bob', 'id', draft());
      session.store.documents['users/alice'] = {'name': 'Alice'};
      await load();
      await notifier().delete('id');
      await notifier().reload();
      expect(records(), isEmpty);
      expect(session.store.documents.length, 2);
    },
  );
  test(
    'repository blocks wrong UID and malformed IDs before any write',
    () async {
      await load();
      final initialReads = session.store.readCalls;
      await expectLater(session.repository.load('bob'), throwsStateError);
      await expectLater(
        session.repository.create('bob', draft()),
        throwsStateError,
      );
      await expectLater(
        session.repository.update('bob', draft().copyWith(id: 'id')),
        throwsStateError,
      );
      await expectLater(
        session.repository.delete('bob', 'id'),
        throwsStateError,
      );
      for (final id in ['', '../id', '..', '.']) {
        await expectLater(
          session.repository.delete('alice', id),
          throwsArgumentError,
        );
      }
      await expectLater(
        session.repository.create('alice', draft(quantity: double.nan)),
        throwsArgumentError,
      );
      expect(
        session.store.addCalls +
            session.store.updateCalls +
            session.store.commitCalls,
        0,
      );
      expect(session.store.readCalls, initialReads);
    },
  );
  test('edit never recreates a deleted Firestore record', () async {
    session.seed('alice', 'id', draft());
    await load();
    session.store.documents.remove('users/alice/waste_records/id');
    await expectLater(
      notifier().save(records().single.copyWith(itemName: 'Changed')),
      throwsA(isA<FirebaseException>()),
    );
    expect(session.store.documents, isEmpty);
    expect(records().single.itemName, 'Apples');
  });
  test('failed create update and delete retain valid state', () async {
    session.seed('alice', 'id', draft());
    await load();
    final failure = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    session.store.addError = failure;
    session.store.updateError = failure;
    session.store.deleteError = failure;
    await expectLater(
      notifier().save(draft(name: 'New meal')),
      throwsA(same(failure)),
    );
    await expectLater(
      notifier().save(records().single.copyWith(itemName: 'Changed')),
      throwsA(same(failure)),
    );
    await expectLater(notifier().delete('id'), throwsA(same(failure)));
    expect(records().single.itemName, 'Apples');
  });
  test('failed refresh retains data and a later retry succeeds', () async {
    session.seed('alice', 'id', draft());
    await load();
    session.store.readError = StateError('network');
    await expectLater(notifier().reload(), throwsStateError);
    expect(records().single.itemName, 'Apples');
    session.store.readError = null;
    session.seed('alice', 'id', draft(name: 'Rice'));
    await notifier().reload();
    expect(records().single.itemName, 'Rice');
  });
  test('double submission is blocked during pending create', () async {
    await load();
    final gate = Completer<void>();
    session.store.addGate = gate.future;
    final pending = notifier().save(draft());
    await expectLater(notifier().save(draft()), throwsStateError);
    gate.complete();
    await pending;
    expect(session.store.addCalls, 1);
    expect(records().length, 1);
  });
  test(
    'account switch and logout never expose previous user records',
    () async {
      session.seed('alice', 'a', draft(name: 'Alice'));
      session.seed('bob', 'b', draft(name: 'Bob'));
      await load();
      session.changeUser('bob');
      await Future<void>.delayed(Duration.zero);
      expect((await load()).single.itemName, 'Bob');
      session.changeUser(null);
      await Future<void>.delayed(Duration.zero);
      expect(await load(), isEmpty);
      await expectLater(notifier().save(draft()), throwsStateError);
    },
  );
  test('old pending write cannot enter new account state', () async {
    await load();
    final gate = Completer<void>();
    session.store.addGate = gate.future;
    final pending = notifier().save(draft(name: 'Alice'));
    session.seed('bob', 'b', draft(name: 'Bob'));
    session.changeUser('bob');
    await Future<void>.delayed(Duration.zero);
    await load();
    gate.complete();
    await pending;
    expect(records().single.itemName, 'Bob');
    expect(
      session.store.documents.keys
          .where((path) => path.startsWith('users/bob/'))
          .length,
      1,
    );
  });
  test('old pending refresh cannot replace new account state', () async {
    session.seed('alice', 'a', draft());
    await load();
    final gate = Completer<void>();
    session.store.readGate = gate.future;
    final pending = notifier().reload();
    final expectation = expectLater(pending, throwsStateError);
    session.store.readGate = null;
    session.seed('bob', 'b', draft(name: 'Bob'));
    session.changeUser('bob');
    await Future<void>.delayed(Duration.zero);
    await load();
    gate.complete();
    await expectation;
    expect(records().single.itemName, 'Bob');
  });
}
