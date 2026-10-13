import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/utils/pantry_duplicate_lookup.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/utils/pantry_expiry_batch.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/duplicate_item_dialog.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_list_tile.dart';

PantryItem _item({
  required String id,
  required String name,
  required DateTime? expiry,
  double quantity = 1,
  PantryLocation location = PantryLocation.refrigerator,
  PantryUnit unit = PantryUnit.bottles,
  String? barcode,
}) {
  return PantryItem(
    id: id,
    firestoreId: id,
    name: name,
    category: PantryCategory.dairy,
    location: location,
    quantity: quantity,
    unit: unit,
    expiryDate: expiry,
    barcode: barcode,
  );
}

PantryProductLookup _lookup(
  Iterable<PantryItem> items, {
  String name = 'Milk',
  PantryLocation location = PantryLocation.refrigerator,
  PantryUnit unit = PantryUnit.bottles,
  DateTime? expiryDate,
  String? barcode,
  String? excludeItemId,
}) {
  return lookupPantryProducts(
    items,
    name: name,
    location: location,
    unit: unit,
    expiryDate: expiryDate,
    barcode: barcode,
    excludeItemId: excludeItemId,
  );
}

void main() {
  final oct10 = DateTime(2026, 10, 10);
  final oct10Afternoon = DateTime(2026, 10, 10, 15, 30);
  final oct18 = DateTime(2026, 10, 18);

  test('same product and exact batch is the exact-duplicate match', () {
    final existing = _item(id: 'A', name: 'Milk', expiry: oct10);
    final lookup = _lookup([existing], expiryDate: oct10);

    expect(lookup.preferred?.exactBatch, isTrue);
    expect(lookup.preferred?.item.id, 'A');
    expect(
      followUpFor(DuplicateItemAction.updateExisting),
      PantryDuplicateFollowUp.openEditor,
    );
  });

  test('same product with a different expiry is a different batch', () {
    final existing = _item(id: 'A', name: 'Milk', expiry: oct10, quantity: 1);
    final lookup = _lookup([existing], expiryDate: oct18);

    expect(lookup.preferred?.exactBatch, isFalse);
    expect(lookup.preferred?.item.id, 'A');
    expect(
      pantryBatchSummary(existing),
      'Refrigerator • 1 bottle • Expires Oct 10, 2026',
    );
  });

  test('the same expiry date with a different product is not a warning', () {
    final existing = _item(id: 'A', name: 'Milk', expiry: oct10);
    expect(
      _lookup([existing], name: 'Yogurt', expiryDate: oct10).isEmpty,
      isTrue,
    );
  });

  test('same product in a different location is a different batch', () {
    final existing = _item(id: 'A', name: 'Milk', expiry: oct10);
    final lookup = _lookup(
      [existing],
      expiryDate: oct10,
      location: PantryLocation.freezer,
    );
    expect(lookup.preferred?.exactBatch, isFalse);
    expect(lookup.preferred?.item.location, PantryLocation.refrigerator);
  });

  test('same product with a different unit is a different batch', () {
    final existing = _item(id: 'A', name: 'Milk', expiry: oct10);
    final lookup = _lookup(
      [existing],
      expiryDate: oct10,
      unit: PantryUnit.liters,
    );
    expect(lookup.isEmpty, isFalse);
    expect(lookup.preferred?.exactBatch, isFalse);
  });

  test('both missing expiry dates can be an exact batch', () {
    final existing = _item(id: 'U', name: 'Milk', expiry: null);
    expect(_lookup([existing]).preferred?.exactBatch, isTrue);
  });

  test('one missing expiry and one dated expiry are different batches', () {
    final existing = _item(id: 'U', name: 'Milk', expiry: null);
    expect(
      _lookup([existing], expiryDate: oct10).preferred?.exactBatch,
      isFalse,
    );
  });

  test('same calendar day with a different time is the same expiry day', () {
    final existing = _item(id: 'A', name: 'Milk', expiry: oct10);
    expect(
      _lookup([existing], expiryDate: oct10Afternoon).preferred?.exactBatch,
      isTrue,
    );
  });

  test('names match after trim, case, and repeated spaces', () {
    expect(normalizePantryBatchName(' MILK  '), 'milk');
    expect(normalizePantryBatchName('Fresh   Milk'), 'fresh milk');
    final existing = _item(id: 'A', name: 'Fresh  Milk', expiry: oct10);
    expect(
      _lookup(
        [existing],
        name: ' fresh   milk ',
        expiryDate: oct10,
      ).preferred?.item.id,
      'A',
    );
  });

  test('confirmed separate save does not reopen and uses a new document', () {
    expect(
      followUpFor(DuplicateItemAction.addSeparately),
      PantryDuplicateFollowUp.saveOnce,
    );
    expect(
      followUpFor(DuplicateItemAction.cancel),
      PantryDuplicateFollowUp.stay,
    );
    expect(followUpFor(null), PantryDuplicateFollowUp.stay);

    const existingId = 'batch-oct-10';
    const generatedId = 'firestore-generated-id';
    expect(generatedId, isNot(existingId));
    expect(generatedId, isNot('Milk'));
  });

  test('Update Existing and View Existing keep the matched document id', () {
    final existing = _item(id: 'batch-oct-10', name: 'Milk', expiry: oct10);
    final lookup = _lookup([existing], expiryDate: oct10);

    expect(lookup.preferred?.item.id, 'batch-oct-10');
    expect(
      followUpFor(DuplicateItemAction.updateExisting),
      PantryDuplicateFollowUp.openEditor,
    );
    expect(
      followUpFor(DuplicateItemAction.viewExisting),
      PantryDuplicateFollowUp.openDetails,
    );
  });

  test('editing excludes the current document', () {
    final current = _item(id: 'A', name: 'Milk', expiry: oct10);
    final other = _item(id: 'B', name: 'Milk', expiry: oct18);
    final withoutSelf = _lookup(
      [current, other],
      expiryDate: oct10,
      excludeItemId: 'A',
    );
    expect(withoutSelf.matches.any((match) => match.item.id == 'A'), isFalse);
    expect(withoutSelf.preferred?.item.id, 'B');
    expect(withoutSelf.preferred?.exactBatch, isFalse);
    expect(
      _lookup(
        [current, other],
        expiryDate: oct10,
        excludeItemId: 'B',
      ).preferred?.item.id,
      'A',
    );
  });

  test('the same barcode with a different expiry is a different batch', () {
    final existing = _item(
      id: 'A',
      name: 'Whole Milk',
      expiry: oct10,
      barcode: '0001234567890',
    );
    final lookup = _lookup(
      [existing],
      name: 'Something else',
      expiryDate: oct18,
      barcode: '0001234567890',
    );
    expect(lookup.preferred?.exactBatch, isFalse);
    expect(lookup.preferred?.item.id, 'A');
    expect(existing.id, isNot('0001234567890'));
  });

  test(
    'different name and barcode with the same expiry is not a duplicate',
    () {
      final existing = _item(
        id: 'A',
        name: 'Milk',
        expiry: oct10,
        barcode: '111',
      );
      expect(
        _lookup(
          [existing],
          name: 'Yogurt',
          expiryDate: oct10,
          barcode: '222',
        ).isEmpty,
        isTrue,
      );
    },
  );

  test('personal and shared lists stay isolated', () {
    final personal = [_item(id: 'personal-milk', name: 'Milk', expiry: oct10)];
    final shared = [_item(id: 'shared-milk', name: 'Milk', expiry: oct10)];

    expect(
      _lookup(personal, expiryDate: oct18).preferred?.item.id,
      'personal-milk',
    );
    expect(
      _lookup(shared, expiryDate: oct10).preferred?.item.id,
      'shared-milk',
    );
    expect(personal.any((item) => item.id == 'shared-milk'), isFalse);
  });

  test('several equal matches ask for a choice instead of guessing', () {
    final first = _item(id: 'A', name: 'Milk', expiry: oct10);
    final second = _item(id: 'B', name: 'Milk', expiry: oct18);
    final lookup = _lookup([first, second], expiryDate: DateTime(2026, 10, 25));

    expect(lookup.needsChoice, isTrue);
    expect(lookup.preferred, isNull);
    expect(
      lookup.matches.map((match) => match.item.id),
      containsAll(['A', 'B']),
    );
  });

  test('rapid Save taps are ignored while one submission is in progress', () {
    final lock = PantrySubmitLock();
    expect(lock.tryAcquire(), isTrue);
    expect(lock.tryAcquire(), isFalse);
    lock.release();
    expect(lock.tryAcquire(), isTrue);
  });

  test('changing one batch leaves the other document unchanged', () {
    final early = _item(id: 'A', name: 'Milk', expiry: oct10, quantity: 1);
    final later = _item(id: 'B', name: 'Milk', expiry: oct18, quantity: 2);
    final changed = early.copyWith(quantity: 9);

    expect(changed.id, 'A');
    expect(later.quantity, 2);
    expect(later.expiryDate, oct18);
  });

  test('name-only shopping lookup is unchanged', () {
    final first = lookupDuplicatePantryItemByName([
      _item(id: 'A', name: 'Milk', expiry: oct10),
      _item(id: 'B', name: 'Milk', expiry: oct18),
    ], 'Milk');
    expect(first?.id, 'A');
  });

  testWidgets('exact batch dialog offers update or a separate entry', (
    tester,
  ) async {
    DuplicateItemAction? result;
    final existing = _item(id: 'batch-oct-10', name: 'Milk', expiry: oct10);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showPantryDuplicateDialog(
                  context: context,
                  existing: existing,
                  candidate: existing,
                  exactBatch: true,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Milk is already in your Refrigerator with the same expiry date.\n\n'
        'Would you like to update the existing batch or add another entry?',
      ),
      findsOneWidget,
    );
    expect(find.text('Update Existing Batch'), findsOneWidget);
    expect(find.text('Add Separately'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, DuplicateItemAction.cancel);
    expect(followUpFor(result), PantryDuplicateFollowUp.stay);
  });

  testWidgets('different batch dialog can add a new batch or view existing', (
    tester,
  ) async {
    final results = <DuplicateItemAction?>[];
    final existing = _item(id: 'A', name: 'Milk', expiry: oct10, quantity: 1);
    final candidate = _item(id: '', name: 'Milk', expiry: oct18, quantity: 2);

    Future<void> open(BuildContext context) async {
      results.add(
        await showPantryDuplicateDialog(
          context: context,
          existing: existing,
          candidate: candidate,
          exactBatch: false,
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Existing batch:'), findsOneWidget);
    expect(find.textContaining('Expires Oct 18, 2026'), findsOneWidget);
    expect(find.text('Add New Batch'), findsOneWidget);
    expect(find.text('View Existing'), findsOneWidget);
    expect(find.text('Update Existing Batch'), findsNothing);

    await tester.tap(find.text('Add New Batch'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Existing'));
    await tester.pumpAndSettle();

    expect(results, [
      DuplicateItemAction.addSeparately,
      DuplicateItemAction.viewExisting,
    ]);
    expect(existing.id, 'A');
  });

  testWidgets('cards keep a stable id and show the expiry date', (
    tester,
  ) async {
    final early = _item(id: 'A', name: 'Milk', expiry: oct10, quantity: 1);
    final later = _item(id: 'B', name: 'Milk', expiry: oct18, quantity: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SizedBox(
                height: kPantryCardExtent,
                child: PantryItemCard(
                  key: ValueKey(early.id),
                  item: early,
                  onEdit: () {},
                  onUsedUp: () {},
                  onDelete: () {},
                  onIncrement: () {},
                  onDecrement: () {},
                ),
              ),
              PantryItemListTile(
                key: ValueKey(later.id),
                item: later,
                onEdit: () {},
                onUsedUp: () {},
                onDelete: () {},
                onIncrement: () {},
                onDecrement: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('A')), findsOneWidget);
    expect(find.byKey(const ValueKey('B')), findsOneWidget);
    expect(find.textContaining('Oct 10, 2026'), findsOneWidget);
    expect(find.textContaining('Oct 18, 2026'), findsOneWidget);
  });
}
