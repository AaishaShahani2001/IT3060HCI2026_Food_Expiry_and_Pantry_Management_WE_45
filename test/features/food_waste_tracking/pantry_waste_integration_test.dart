import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/automatic_waste_candidate.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_summary.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_scope.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/pantry_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/waste_tracker_screen.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';

import 'support/waste_test_session.dart';

PantryItem stock({
  String id = 'milk',
  String name = 'Milk',
  DateTime? expiry,
  bool noExpiry = false,
  double quantity = 1,
  double? originalQuantity,
  PantryUnit unit = PantryUnit.bottles,
  double? priceAmount = 800,
  PantryPriceType priceType = PantryPriceType.totalPrice,
}) => PantryItem(
  id: id,
  firestoreId: id,
  name: name,
  category: PantryCategory.dairy,
  location: PantryLocation.refrigerator,
  quantity: quantity,
  originalQuantity: originalQuantity,
  unit: unit,
  priceAmount: priceAmount,
  priceType: priceType,
  expiryDate: noExpiry ? null : expiry ?? DateTime(2026, 9, 15),
);

void main() {
  late WasteTestSession session;
  setUp(() => session = WasteTestSession());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await session.changes.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodWasteRepositoryProvider.overrideWithValue(session.repository),
          wasteAuthUidProvider.overrideWith((ref) => session.auth()),
          wasteClockProvider.overrideWithValue(() => wasteTestNow),
          wastePantryServiceProvider.overrideWithValue(session.pantry),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WasteTrackerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(WasteTrackerScreen)),
  );

  List<FoodWasteRecord> records(WidgetTester tester) =>
      container(tester).read(foodWasteProvider).requireValue;

  testWidgets(
    'only actually expired positive remaining stock is auto-recorded',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.seed(
        'alice',
        stock(id: 'today', name: 'Today', expiry: wasteTestNow),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'soon', name: 'Soon', expiry: DateTime(2026, 9, 17)),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'no-date', name: 'No date', noExpiry: true),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'zero', name: 'Zero', quantity: 0),
      );

      await open(tester);

      expect(records(tester), hasLength(1));
      expect(records(tester).single.itemName, 'Milk');
      expect(records(tester).single.quantity, 1);
      expect(records(tester).single.unit, 'bottle');
      expect(records(tester).single.wastedAt, DateTime(2026, 9, 16));
      expect(find.text('Expired Pantry Items'), findsNothing);
      expect(find.text('Auto-recorded from expired Pantry stock'), findsOne);
    },
  );

  testWidgets('reconcile, refresh and screen reopen stay idempotent', (
    tester,
  ) async {
    session.pantry.seed('alice', stock());
    await open(tester);
    final eventId = records(tester).single.id;

    await container(tester).read(foodWasteProvider.notifier).reload();
    session.pantry.seed('alice', stock());
    await tester.pumpAndSettle();
    expect(records(tester), hasLength(1));
    expect(records(tester).single.id, eventId);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodWasteRepositoryProvider.overrideWithValue(session.repository),
          wasteAuthUidProvider.overrideWith((ref) => session.auth()),
          wasteClockProvider.overrideWithValue(() => wasteTestNow),
          wastePantryServiceProvider.overrideWithValue(session.pantry),
        ],
        child: const MaterialApp(home: WasteTrackerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(session.store.transactionSetCalls, 1);
    expect(
      session.store.documents.keys.where((path) => path.contains(eventId!)),
      hasLength(1),
    );
  });

  testWidgets('automatic reconciliation waits for a busy Waste save', (
    tester,
  ) async {
    await open(tester);
    final gate = Completer<void>();
    session.store.addGate = gate.future;
    final pendingSave = container(
      tester,
    ).read(foodWasteProvider.notifier).save(draft(name: 'Manual record'));

    session.pantry.seed('alice', stock());
    await tester.pump();
    expect(session.store.transactionCalls, 0);

    gate.complete();
    await pendingSave;
    await tester.pumpAndSettle();

    expect(records(tester).map((record) => record.itemName), {
      'Manual record',
      'Milk',
    });
    expect(session.store.transactionSetCalls, 1);
  });

  testWidgets('multiple busy updates coalesce to one automatic Waste record', (
    tester,
  ) async {
    await open(tester);
    final gate = Completer<void>();
    session.store.addGate = gate.future;
    final pendingSave = container(
      tester,
    ).read(foodWasteProvider.notifier).save(draft(name: 'Manual record'));

    session.pantry.seed('alice', stock());
    await tester.pump();
    session.pantry.seed('alice', stock(quantity: 2));
    await tester.pump();
    session.pantry.seed('alice', stock(quantity: 3));
    await tester.pump();
    expect(session.store.transactionCalls, 0);

    gate.complete();
    await pendingSave;
    await tester.pumpAndSettle();

    final automatic = records(
      tester,
    ).where((record) => record.isAutomaticExpiry).toList();
    expect(automatic, hasLength(1));
    expect(automatic.single.quantity, 3);
    expect(session.store.transactionSetCalls, 1);
    expect(
      session.store.documents.keys.where(
        (path) => path.endsWith('/${automatic.single.id}'),
      ),
      hasLength(1),
    );
  });

  testWidgets('account change discards reconciliation waiting for idle', (
    tester,
  ) async {
    await open(tester);
    final gate = Completer<void>();
    session.store.addGate = gate.future;
    final pendingSave = container(
      tester,
    ).read(foodWasteProvider.notifier).save(draft(name: 'Alice manual'));

    session.pantry.seed('alice', stock());
    await tester.pump();
    session.changeUser('bob');
    await tester.pump();
    gate.complete();
    await pendingSave;
    await tester.pumpAndSettle();

    expect(records(tester), isEmpty);
    expect(session.store.transactionSetCalls, 0);
    expect(
      session.store.documents.keys.where(
        (path) =>
            path.contains(automaticWasteEventId('milk', DateTime(2026, 9, 15))),
      ),
      isEmpty,
    );
  });

  test('automatic candidates use current Pantry price semantics safely', () {
    FoodWasteRecord automatic(PantryItem item) => PantryWasteSource(
      WasteScope.personal(actorUid: 'alice'),
      item,
    ).automaticCandidate().record;

    expect(
      automatic(
        stock(
          quantity: 1.5,
          unit: PantryUnit.kg,
          priceAmount: 400,
          priceType: PantryPriceType.unitPrice,
        ),
      ).estimatedValue,
      600,
    );
    expect(
      automatic(
        stock(
          quantity: 500,
          unit: PantryUnit.g,
          priceAmount: 400,
          priceType: PantryPriceType.unitPrice,
        ),
      ).estimatedValue,
      200,
    );
    expect(
      automatic(
        stock(
          quantity: 250,
          unit: PantryUnit.ml,
          priceAmount: 300,
          priceType: PantryPriceType.unitPrice,
        ),
      ).estimatedValue,
      75,
    );
    expect(
      automatic(
        stock(
          quantity: 1,
          originalQuantity: 2,
          priceAmount: 800,
          priceType: PantryPriceType.totalPrice,
        ),
      ).estimatedValue,
      400,
    );
    expect(automatic(stock(priceAmount: null)).estimatedValue, 0);
    expect(
      automatic(
        stock(
          originalQuantity: 0,
          priceAmount: 800,
          priceType: PantryPriceType.totalPrice,
        ),
      ).estimatedValue,
      0,
    );
  });

  testWidgets('UID isolation applies to reads, event IDs and stored records', (
    tester,
  ) async {
    session.pantry.seed('alice', stock(id: 'shared', name: 'Alice milk'));
    session.pantry.seed('bob', stock(id: 'shared', name: 'Bob milk'));
    await open(tester);
    expect(records(tester).single.itemName, 'Alice milk');
    expect(
      session.store.documents.keys.single,
      startsWith('users/alice/waste_records/'),
    );

    session.changeUser('bob');
    await tester.pumpAndSettle();
    expect(records(tester).single.itemName, 'Bob milk');
    expect(
      session.store.documents.keys.where(
        (path) => path.startsWith('users/bob/waste_records/'),
      ),
      hasLength(1),
    );
  });

  testWidgets('failed automatic write is safe and retries on Pantry refresh', (
    tester,
  ) async {
    session.pantry.seed('alice', stock());
    session.store.transactionError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await open(tester);
    expect(records(tester), isEmpty);
    expect(session.store.documents, isEmpty);

    session.store.transactionError = null;
    session.pantry.seed('alice', stock());
    await tester.pumpAndSettle();
    expect(records(tester).single.itemName, 'Milk');
  });

  testWidgets(
    'Not Wasted suppresses the same event while a different event still records',
    (tester) async {
      session.pantry.seed('alice', stock());
      await open(tester);
      expect(records(tester), hasLength(1));

      await tester.tap(find.byTooltip('Actions for Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not Wasted'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as not wasted?'), findsOne);
      await tester.tap(find.widgetWithText(FilledButton, 'Not Wasted'));
      await tester.pumpAndSettle();
      expect(records(tester), isEmpty);

      session.pantry.seed('alice', stock());
      await tester.pumpAndSettle();
      expect(records(tester), isEmpty);
      final suppressed = session.store.documents.values.single;
      expect(suppressed['notWasted'], isTrue);

      session.pantry.seed(
        'alice',
        stock(id: 'cheese', name: 'Cheese', expiry: DateTime(2026, 9, 14)),
      );
      await tester.pumpAndSettle();
      expect(records(tester).single.itemName, 'Cheese');
    },
  );

  testWidgets(
    'automatic records use existing dashboard and period calculations',
    (tester) async {
      session.pantry.seed(
        'alice',
        stock(quantity: 1, originalQuantity: 2, priceAmount: 800),
      );
      session.seed(
        'alice',
        'manual-week',
        draft(name: 'Rice', unit: 'kg', date: DateTime(2026, 9, 14)),
      );
      session.seed(
        'alice',
        'previous-week',
        draft(name: 'Bread', date: DateTime(2026, 9, 7)),
      );
      await open(tester);

      final all = records(tester);
      final today = WasteSummary(all, WastePeriod.today, wasteTestNow);
      final week = WasteSummary(all, WastePeriod.week, wasteTestNow);
      final month = WasteSummary(all, WastePeriod.month, wasteTestNow);
      expect(today.count, 1);
      expect(today.estimatedValue, 400);
      expect(week.count, 2);
      expect(week.mixedUnits, isTrue);
      expect(week.quantityDetail, contains('kg'));
      expect(week.quantityDetail, contains('bottle'));
      expect(week.previousCount, 1);
      expect(month.count, 3);
      expect(find.text('Milk'), findsOne);
      expect(find.text('Rs. 400 • Today'), findsOne);
    },
  );

  testWidgets('manual Record Waste remains available beside automation', (
    tester,
  ) async {
    session.pantry.seed('alice', stock());
    await open(tester);
    expect(find.widgetWithText(FilledButton, 'Record Waste'), findsOne);
    await tester.tap(find.widgetWithText(FilledButton, 'Record Waste'));
    await tester.pumpAndSettle();
    expect(find.text('Record Waste'), findsWidgets);
    expect(find.byKey(const ValueKey('waste-name')), findsOne);
  });

  test(
    'automatic metadata is deterministic and old records remain compatible',
    () {
      final expiry = DateTime(2026, 9, 15, 23, 59);
      expect(
        automaticWasteEventId('milk', expiry),
        automaticWasteEventId('milk', DateTime(2026, 9, 15)),
      );
      expect(
        automaticWasteEventId('milk', expiry),
        isNot(automaticWasteEventId('milk', DateTime(2026, 9, 16))),
      );

      final old = FoodWasteRecord.fromMap('old', draft().toMap());
      expect(old.source, isNull);
      expect(old.sourceExpiryDate, isNull);
      expect(old.notWasted, isFalse);
    },
  );
}
