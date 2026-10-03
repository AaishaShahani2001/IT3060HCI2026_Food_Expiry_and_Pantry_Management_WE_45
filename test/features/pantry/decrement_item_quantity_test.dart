import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_firestore_service.dart';
import 'package:food_expiry_and_pantry_management/features/shared_pantry/data/shared_pantry_service.dart';

import 'support/fake_pantry_firestore.dart';

const personalPath = 'users/alice/pantryItems/milk';
const sharedPath = 'pantries/house/items/milk';
const memberPath = 'pantries/house/members/alice';

Map<String, dynamic> pantryDocument({
  Object? quantity = 5,
  String name = 'Milk',
  bool includeQuantity = true,
}) {
  return {
    'name': name,
    'category': 'dairy',
    'location': 'refrigerator',
    'originalQuantity': 5,
    'unit': 'liters',
    'priceType': 'totalPrice',
    'priceAmount': 400,
    'price': 400,
    'updatedAt': 'previous',
    if (includeQuantity) 'quantity': quantity,
  };
}

void seed(FakePantryFirestore store, String path, Map<String, dynamic> data) {
  store.documents[path] = Map<String, dynamic>.of(data);
}

PantryFirestoreService serviceFor(
  FakePantryFirestore store, {
  String? uid = 'alice',
  ActivePantryContext context = const ActivePantryContext(
    pantryType: 'personal',
    pantryId: null,
  ),
}) {
  return PantryFirestoreService(
    firestore: store,
    currentUserId: () => uid,
    activePantryContext: () async => context,
  );
}

void expectDocumentUnchanged(
  Map<String, dynamic> saved,
  Map<String, dynamic> original,
) {
  expect(saved.keys.toSet(), original.keys.toSet());
  for (final key in original.keys) {
    final left = saved[key];
    final right = original[key];
    if (left is num && right is num && left.isNaN && right.isNaN) continue;
    expect(left, right, reason: key);
  }
}

void expectOnlyQuantityAndUpdatedAtChanged({
  required FakePantryFirestore store,
  required String path,
  required Map<String, dynamic> original,
  required double quantity,
}) {
  final saved = store.documents[path]!;
  expect(saved['quantity'], quantity);
  expect(saved['updatedAt'], isA<FieldValue>());
  expect(store.transactionUpdates, hasLength(1));
  expect(store.transactionUpdates.single.keys.toSet(), {
    'quantity',
    'updatedAt',
  });
  expect(store.directUpdateCalls, 0);
  expect(store.deleteCalls, 0);
  for (final entry in original.entries) {
    if (entry.key == 'quantity' || entry.key == 'updatedAt') continue;
    expect(saved[entry.key], entry.value, reason: entry.key);
  }
}

void main() {
  test('decrements part of an item quantity', () async {
    final store = FakePantryFirestore();
    final original = pantryDocument(quantity: 5);
    seed(store, personalPath, original);

    final remaining = await serviceFor(
      store,
    ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 2);

    expect(remaining, 3);
    expectOnlyQuantityAndUpdatedAtChanged(
      store: store,
      path: personalPath,
      original: original,
      quantity: 3,
    );
  });

  test('exact decrement stores quantity 0 and keeps the document', () async {
    final store = FakePantryFirestore();
    final original = pantryDocument(quantity: 2.5);
    seed(store, personalPath, original);

    final remaining = await serviceFor(
      store,
    ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 2.5);

    expect(remaining, 0);
    expect(store.documents.containsKey(personalPath), isTrue);
    expect(store.deleteCalls, 0);
    expectOnlyQuantityAndUpdatedAtChanged(
      store: store,
      path: personalPath,
      original: original,
      quantity: 0,
    );
  });

  test('a floating-point depletion is stored as zero', () async {
    final store = FakePantryFirestore();
    seed(store, personalPath, pantryDocument(quantity: 0.3));

    final remaining = await serviceFor(
      store,
    ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 0.1 + 0.2);

    expect(0.1 + 0.2, isNot(0.3));
    expect(remaining, 0);
    expect(store.documents[personalPath]!['quantity'], 0);
    expect(store.documents.containsKey(personalPath), isTrue);
    expect(store.deleteCalls, 0);
  });

  test('zero decrement is rejected', () async {
    final store = FakePantryFirestore();
    final original = pantryDocument();
    seed(store, personalPath, original);

    await expectLater(
      serviceFor(
        store,
      ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 0),
      throwsA(
        isA<InvalidPantryQuantityException>().having(
          (error) => error.message,
          'message',
          'The decrement amount must be greater than zero.',
        ),
      ),
    );
    expect(store.documents[personalPath], original);
    expect(store.transactionUpdates, isEmpty);
  });

  test('negative decrement is rejected', () async {
    final store = FakePantryFirestore();
    final original = pantryDocument();
    seed(store, personalPath, original);

    await expectLater(
      serviceFor(
        store,
      ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: -1),
      throwsA(isA<InvalidPantryQuantityException>()),
    );
    expect(store.documents[personalPath], original);
    expect(store.transactionUpdates, isEmpty);
  });

  test('NaN and infinite decrements are rejected', () async {
    for (final amount in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final store = FakePantryFirestore();
      final original = pantryDocument();
      seed(store, personalPath, original);

      await expectLater(
        serviceFor(store).decrementItemQuantity(
          userId: 'alice',
          itemId: 'milk',
          amount: amount,
        ),
        throwsA(
          isA<InvalidPantryQuantityException>().having(
            (error) => error.message,
            'message',
            'The decrement amount must be a finite number greater than zero.',
          ),
        ),
      );
      expect(store.documents[personalPath], original);
      expect(store.transactionUpdates, isEmpty);
    }
  });

  test('an amount greater than the latest quantity is rejected', () async {
    final store = FakePantryFirestore();
    final original = pantryDocument(quantity: 3);
    seed(store, personalPath, original);

    await expectLater(
      serviceFor(
        store,
      ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 4),
      throwsA(
        isA<InsufficientPantryQuantityException>()
            .having((error) => error.requested, 'requested', 4)
            .having((error) => error.available, 'available', 3),
      ),
    );
    expect(store.documents[personalPath], original);
    expect(store.transactionUpdates, isEmpty);
    expect(store.deleteCalls, 0);
  });

  test('a missing item is rejected', () async {
    final store = FakePantryFirestore();

    await expectLater(
      serviceFor(
        store,
      ).decrementItemQuantity(userId: 'alice', itemId: 'missing', amount: 1),
      throwsA(
        isA<PantryItemNotFoundException>().having(
          (error) => error.itemId,
          'itemId',
          'missing',
        ),
      ),
    );
    expect(store.documents, isEmpty);
    expect(store.transactionUpdates, isEmpty);
    expect(store.deleteCalls, 0);
  });

  test('missing or invalid stored quantity is rejected', () async {
    final cases = <Map<String, dynamic>>[
      pantryDocument(includeQuantity: false),
      pantryDocument(quantity: null),
      pantryDocument(quantity: '5'),
      pantryDocument(quantity: -1),
      pantryDocument(quantity: double.nan),
      pantryDocument(quantity: double.infinity),
      pantryDocument(quantity: double.negativeInfinity),
      pantryDocument(quantity: true),
    ];

    for (final original in cases) {
      final store = FakePantryFirestore();
      seed(store, personalPath, original);

      await expectLater(
        serviceFor(
          store,
        ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 1),
        throwsA(isA<InvalidPantryQuantityException>()),
      );
      expectDocumentUnchanged(store.documents[personalPath]!, original);
      expect(store.transactionUpdates, isEmpty);
    }
  });

  test(
    'personal pantry references resolve under users/{uid}/pantryItems',
    () async {
      final store = FakePantryFirestore();
      final personal = pantryDocument(quantity: 5);
      final shared = pantryDocument(quantity: 5);
      seed(store, personalPath, personal);
      seed(store, sharedPath, shared);

      await serviceFor(
        store,
      ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 2);

      expect(store.documents[personalPath]!['quantity'], 3);
      expect(store.documents[sharedPath], shared);
    },
  );

  test(
    'shared pantry references resolve under pantries/{pantryId}/items',
    () async {
      final store = FakePantryFirestore();
      final personal = pantryDocument(quantity: 5);
      final shared = pantryDocument(quantity: 5, name: 'Rice');
      seed(store, personalPath, personal);
      seed(store, sharedPath, shared);
      seed(store, memberPath, {'uid': 'alice', 'role': 'member'});

      await serviceFor(
        store,
        context: const ActivePantryContext(
          pantryType: 'shared',
          pantryId: 'house',
        ),
      ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 2);

      expect(store.documents[sharedPath]!['quantity'], 3);
      expect(store.documents[sharedPath]!['name'], 'Rice');
      expect(store.documents[personalPath], personal);
    },
  );

  test('family pantry references use the shared pantry item path', () async {
    final store = FakePantryFirestore();
    final shared = pantryDocument(quantity: 8);
    seed(store, sharedPath, shared);
    seed(store, memberPath, {'uid': 'alice', 'role': 'owner'});

    final remaining = await serviceFor(
      store,
      context: const ActivePantryContext(
        pantryType: 'family',
        pantryId: 'house',
      ),
    ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 1);

    expect(remaining, 7);
    expect(store.documents[sharedPath]!['quantity'], 7);
    expect(store.documents.containsKey(personalPath), isFalse);
  });

  test('unauthorized shared access is rejected', () async {
    Future<void> reject(FakePantryFirestore store) async {
      final original = Map<String, dynamic>.of(store.documents[sharedPath]!);
      await expectLater(
        serviceFor(
          store,
          context: const ActivePantryContext(
            pantryType: 'shared',
            pantryId: 'house',
          ),
        ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 1),
        throwsA(isA<PantryAccessDeniedException>()),
      );
      expect(store.documents[sharedPath], original);
      expect(store.transactionAttempts, 0);
      expect(store.transactionUpdates, isEmpty);
      expect(store.deleteCalls, 0);
    }

    final missingMember = FakePantryFirestore();
    seed(missingMember, sharedPath, pantryDocument());
    seed(missingMember, 'pantries/other/members/alice', {
      'uid': 'alice',
      'role': 'member',
    });
    await reject(missingMember);

    final mismatchedMember = FakePantryFirestore();
    seed(mismatchedMember, sharedPath, pantryDocument());
    seed(mismatchedMember, memberPath, {'uid': 'bob', 'role': 'member'});
    await reject(mismatchedMember);
  });

  test('a different signed-in user id is rejected', () async {
    final store = FakePantryFirestore();
    final original = pantryDocument();
    seed(store, personalPath, original);

    await expectLater(
      serviceFor(
        store,
      ).decrementItemQuantity(userId: 'bob', itemId: 'milk', amount: 1),
      throwsA(isA<PantryAccessDeniedException>()),
    );
    expect(store.documents[personalPath], original);
    expect(store.transactionAttempts, 0);
  });

  test('a signed-out caller is rejected', () async {
    final store = FakePantryFirestore();
    final original = pantryDocument();
    seed(store, personalPath, original);

    await expectLater(
      serviceFor(
        store,
        uid: null,
      ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 1),
      throwsA(
        isA<PantryFirestoreException>().having(
          (error) => error.message,
          'message',
          kPantrySignInRequiredMessage,
        ),
      ),
    );
    expect(store.documents[personalPath], original);
    expect(store.transactionAttempts, 0);
  });

  test('a concurrent write is retried from the latest quantity', () async {
    final store = FakePantryFirestore();
    seed(store, personalPath, pantryDocument(quantity: 10));
    store.contendOnNextTransactionRead(
      personalPath,
      pantryDocument(quantity: 7, name: 'Oat Milk'),
    );

    final remaining = await serviceFor(
      store,
    ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 2);

    expect(remaining, 5);
    expect(store.transactionAttempts, 2);
    expect(store.directUpdateCalls, 0);
    expect(store.documents[personalPath]!['quantity'], 5);
    expect(store.documents[personalPath]!['name'], 'Oat Milk');
    expect(store.documents[personalPath]!['originalQuantity'], 5);
    expect(store.transactionUpdates.single.keys.toSet(), {
      'quantity',
      'updatedAt',
    });
  });

  test('a concurrent drop below the request is not clamped', () async {
    final store = FakePantryFirestore();
    seed(store, personalPath, pantryDocument(quantity: 10));
    store.contendOnNextTransactionRead(
      personalPath,
      pantryDocument(quantity: 3, name: 'Oat Milk'),
    );

    await expectLater(
      serviceFor(
        store,
      ).decrementItemQuantity(userId: 'alice', itemId: 'milk', amount: 4),
      throwsA(
        isA<InsufficientPantryQuantityException>()
            .having((error) => error.requested, 'requested', 4)
            .having((error) => error.available, 'available', 3),
      ),
    );
    expect(store.transactionAttempts, 2);
    expect(store.transactionUpdates, isEmpty);
    expect(store.directUpdateCalls, 0);
    expect(store.documents[personalPath]!['quantity'], 3);
    expect(store.documents[personalPath]!['name'], 'Oat Milk');
  });
}
