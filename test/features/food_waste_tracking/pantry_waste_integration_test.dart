import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_summary.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/pantry_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/waste_tracker_screen.dart';
import 'support/waste_test_session.dart';

PantryItem stock({
  String id = 'milk',
  String name = 'Milk',
  DateTime? expiry,
  double quantity = 4,
}) => PantryItem(
  id: id,
  firestoreId: id,
  name: name,
  category: PantryCategory.dairy,
  location: PantryLocation.refrigerator,
  quantity: quantity,
  unit: PantryUnit.bottles,
  price: 250,
  expiryDate: expiry ?? DateTime(2026, 9, 15),
);

void main() {
  late WasteTestSession session;
  setUp(() => session = WasteTestSession());

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(430, 1700),
    double scale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size;
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
          home: const WasteTrackerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> prefill(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('waste-pantry-milk')));
  Future<void> save(WidgetTester tester, {String quantity = '2'}) async {
    await tester.enterText(
      find.byKey(const ValueKey('waste-quantity')),
      quantity,
    );
    await tap(tester, find.byKey(const ValueKey('save-waste')));
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(WasteTrackerScreen)),
  );

  testWidgets(
    'expired cards have category chips, grouped counts, timing and separate actions',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.seed('alice', stock(id: 'cheese', name: 'Cheese'));
      session.pantry.seed(
        'alice',
        stock(
          id: 'apple',
          name: 'Apple',
          expiry: DateTime(2026, 9, 14),
        ).copyWith(category: PantryCategory.fruits, unit: PantryUnit.items),
      );
      session.pantry.seed(
        'alice',
        stock(
          id: 'carrot',
          name: 'Carrot',
        ).copyWith(category: PantryCategory.vegetables),
      );
      session.pantry.seed(
        'alice',
        stock(
          id: 'juice',
          name: 'Juice',
        ).copyWith(category: PantryCategory.beverages),
      );
      session.pantry.seed(
        'alice',
        stock(
          id: 'unknown',
          name: 'Custom food',
        ).copyWith(category: PantryCategory.fromStorage('unknown-category')),
      );
      await open(tester);
      for (final category in [
        'all',
        'dairy',
        'fruits',
        'vegetables',
        'beverages',
        'other',
      ]) {
        expect(
          find.byKey(ValueKey('expired-filter-$category')),
          findsOneWidget,
        );
      }
      for (final id in [
        'milk',
        'cheese',
        'apple',
        'carrot',
        'juice',
        'unknown',
      ]) {
        expect(find.byKey(ValueKey('expired-card-$id')), findsOneWidget);
        expect(find.byKey(ValueKey('waste-pantry-$id')), findsOneWidget);
      }
      expect(find.text('Dairy (2)'), findsOneWidget);
      expect(find.text('Fruits (1)'), findsOneWidget);
      expect(find.text('Other (1)'), findsOneWidget);
      expect(find.text('Expired 2 days ago'), findsOneWidget);
      expect(find.text('Expired 1 day ago'), findsNWidgets(5));
      expect(session.store.addCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'filtering changes visible groups only and preserves prefilled action',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.seed(
        'alice',
        stock(
          id: 'apple',
          name: 'Apple',
        ).copyWith(category: PantryCategory.fruits),
      );
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('expired-filter-fruits')));
      expect(find.text('Dairy (1)'), findsNothing);
      expect(find.byKey(const ValueKey('expired-card-milk')), findsNothing);
      expect(find.text('Fruits (1)'), findsOneWidget);
      expect(find.text('2 items may need attention'), findsOneWidget);
      expect(session.store.addCalls, 0);
      await tap(tester, find.byKey(const ValueKey('waste-pantry-apple')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('waste-name')))
            .controller!
            .text,
        'Apple',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('expired-filter-all')));
      expect(find.byKey(const ValueKey('expired-card-milk')), findsOneWidget);
      expect(find.byKey(const ValueKey('expired-card-apple')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing selected category falls back to All; next user never inherits filter',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.seed(
        'alice',
        stock(
          id: 'apple',
          name: 'Apple',
        ).copyWith(category: PantryCategory.fruits),
      );
      session.pantry.seed(
        'bob',
        stock(
          id: 'carrot',
          name: 'Bob carrot',
        ).copyWith(category: PantryCategory.vegetables),
      );
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('expired-filter-fruits')));
      session.pantry.seed(
        'alice',
        stock(
          id: 'apple',
          name: 'Apple',
          quantity: 0,
        ).copyWith(category: PantryCategory.fruits),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('expired-filter-fruits')), findsNothing);
      expect(find.byKey(const ValueKey('expired-card-milk')), findsOneWidget);
      session.changeUser('bob');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('expired-card-milk')), findsNothing);
      expect(find.text('Bob carrot'), findsOneWidget);
      expect(find.text('Vegetables (1)'), findsOneWidget);
    },
  );
  testWidgets('no eligible items hides title, chips and cards completely', (
    tester,
  ) async {
    session.pantry.seed('alice', stock(expiry: DateTime(2026, 10, 1)));
    await open(tester);
    expect(find.text('Expired Pantry Items'), findsNothing);
    expect(find.byKey(const ValueKey('expired-filter-all')), findsNothing);
    expect(find.byKey(const ValueKey('expired-card-milk')), findsNothing);
  });

  testWidgets(
    'only expired positive stock appears; expiry alone never adds Waste or Home totals',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.seed(
        'alice',
        stock(id: 'soon', name: 'Soon', expiry: DateTime(2026, 9, 17)),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'today', name: 'Expires today', expiry: wasteTestNow),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'valid', name: 'Valid', expiry: DateTime(2026, 10, 1)),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'zero', name: 'Empty stock', quantity: 0),
      );
      session.pantry.seed('bob', stock(id: 'private', name: 'Private'));
      await open(tester);
      expect(find.text('Expired Pantry Items'), findsOneWidget);
      expect(find.text('1 item may need attention'), findsOneWidget);
      for (final name in [
        'Soon',
        'Valid',
        'Private',
        'Expires today',
        'Empty stock',
      ]) {
        expect(find.text(name), findsNothing);
      }
      final records = container(tester).read(foodWasteProvider).requireValue;
      expect(WasteSummary(records, WastePeriod.week, wasteTestNow).count, 0);
      expect(session.store.addCalls, 0);
    },
  );
  testWidgets(
    'Pantry action prefills all fields; partial stock decreases only after saved and confirmed',
    (tester) async {
      session.pantry.seed('alice', stock());
      await open(tester);
      await prefill(tester);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('waste-name')))
            .controller!
            .text,
        'Milk',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('waste-quantity')))
            .controller!
            .text,
        '4',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('waste-value')))
            .controller!
            .text,
        '1000',
      );
      expect(find.text('bottle'), findsWidgets);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Date: 16/09/2026'), findsOneWidget);
      await save(tester);
      expect(find.text('Update Pantry?'), findsOneWidget);
      expect(session.store.addCalls, 1);
      expect(session.pantry.reductions, isEmpty);
      expect(session.pantry.items['alice']!.single.quantity, 4);
      await tap(tester, find.text('Remove from Pantry'));
      expect(session.pantry.items['alice']!.single.quantity, 2);
      expect(
        session.store.documents.values.single['sourcePantryItemId'],
        'milk',
      );
      expect(session.store.documents.values.single['source'], 'pantry');
      expect(
        WasteSummary(
          container(tester).read(foodWasteProvider).requireValue,
          WastePeriod.week,
          wasteTestNow,
        ).count,
        1,
      );
    },
  );
  testWidgets('full waste uses existing zero-stock flow and hides suggestion', (
    tester,
  ) async {
    session.pantry.seed('alice', stock());
    await open(tester);
    await prefill(tester);
    await save(tester, quantity: '4');
    await tap(tester, find.text('Remove from Pantry'));
    expect(session.pantry.items['alice']!.single.quantity, 0);
    expect(find.text('Expired Pantry Items'), findsNothing);
  });
  for (final action in ['Keep Pantry Unchanged', 'Cancel']) {
    testWidgets('$action keeps stock but notifies that Waste remains saved', (
      tester,
    ) async {
      session.pantry.seed('alice', stock());
      await open(tester);
      await prefill(tester);
      await save(tester);
      expect(
        find.textContaining('does not undo the saved Waste record'),
        findsOneWidget,
      );
      await tap(tester, find.text(action));
      expect(session.pantry.items['alice']!.single.quantity, 4);
      expect(session.pantry.reductions, isEmpty);
      expect(session.store.addCalls, 1);
    });
  }
  testWidgets('failed Waste save never offers or writes Pantry reduction', (
    tester,
  ) async {
    session.pantry.seed('alice', stock());
    session.store.addError = StateError('offline');
    await open(tester);
    await prefill(tester);
    await save(tester);
    expect(find.text('Update Pantry?'), findsNothing);
    expect(session.store.documents, isEmpty);
    expect(session.pantry.reductions, isEmpty);
    expect(session.pantry.items['alice']!.single.quantity, 4);
  });
  testWidgets(
    'Pantry failure reports partial success without another Waste save',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.failure = StateError('offline');
      await open(tester);
      await prefill(tester);
      await save(tester);
      await tap(tester, find.text('Remove from Pantry'));
      expect(
        find.text('Waste was recorded, but Pantry could not be updated.'),
        findsOneWidget,
      );
      expect(session.store.addCalls, 1);
      expect(session.pantry.items['alice']!.single.quantity, 4);
    },
  );
  testWidgets(
    'linked duplicate warns even with changed date or quantity; Save Anyway stays explicit',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.seed(
        'alice',
        'old',
        PantryWasteSource('alice', stock()).draft(DateTime(2026, 9, 1)),
      );
      await open(tester);
      await prefill(tester);
      await save(tester);
      expect(
        find.text('This expired item may already have been recorded as waste.'),
        findsOneWidget,
      );
      await tap(tester, find.text('Cancel'));
      expect(session.store.addCalls, 0);
      await save(tester);
      await tap(tester, find.text('Save Anyway'));
      await tap(tester, find.text('Keep Pantry Unchanged'));
      expect(session.store.addCalls, 1);
    },
  );
  testWidgets(
    'account switch hides old suggestions and prevents old confirmation writing',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.seed('bob', stock(name: 'Bob milk'));
      await open(tester);
      await prefill(tester);
      await save(tester);
      session.changeUser('bob');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Remove from Pantry'));
      expect(session.pantry.reductions, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Bob milk'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
      session.changeUser(null);
      await tester.pumpAndSettle();
      expect(find.text('Expired Pantry Items'), findsNothing);
    },
  );
  testWidgets(
    'changed units disable stock removal but still allow Waste logging',
    (tester) async {
      session.pantry.seed('alice', stock());
      await open(tester);
      await prefill(tester);
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await tap(tester, find.text('kg').last);
      await save(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Remove from Pantry'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.text('Keep Pantry Unchanged'));
      expect(session.pantry.reductions, isEmpty);
    },
  );
  testWidgets('pending Pantry edits block unsafe removal', (tester) async {
    session.pantry.seed('alice', stock());
    await open(tester);
    final ref = container(tester);
    await prefill(tester);
    await save(tester);
    ref.read(pantryPendingQuantitiesProvider.notifier).setQuantity('milk', 3);
    await tap(tester, find.text('Remove from Pantry'));
    expect(session.pantry.reductions, isEmpty);
    expect(
      find.text('Waste was recorded, but Pantry could not be updated.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'stock changes while form is open cannot cause negative quantity',
    (tester) async {
      session.pantry.seed('alice', stock());
      await open(tester);
      await prefill(tester);
      await save(tester);
      session.pantry.seed('alice', stock(quantity: 1));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Remove from Pantry'));
      expect(session.pantry.reductions, isEmpty);
      expect(session.pantry.items['alice']!.single.quantity, 1);
      expect(session.store.addCalls, 1);
      expect(
        find.text('Waste was recorded, but Pantry could not be updated.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'pending reduction remains bound to original UID after account switch',
    (tester) async {
      session.pantry.seed('alice', stock());
      session.pantry.seed('bob', stock(name: 'Bob stock', quantity: 100));
      await open(tester);
      await prefill(tester);
      await save(tester);
      final gate = Completer<void>();
      session.pantry.gate = gate.future;
      await tester.tap(find.text('Remove from Pantry'));
      await tester.pump();
      session.changeUser('bob');
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(session.pantry.reductions.single.$1, 'alice');
      expect(session.pantry.items['bob']!.single.quantity, 100);
      expect(find.textContaining('Your account changed.'), findsOneWidget);
    },
  );
  testWidgets('rapid Remove taps and repeated receipt cannot subtract twice', (
    tester,
  ) async {
    session.pantry.seed('alice', stock());
    await open(tester);
    final ref = container(tester);
    await prefill(tester);
    await save(tester);
    final gate = Completer<void>();
    session.pantry.gate = gate.future;
    final button = find.text('Remove from Pantry');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(session.pantry.reductions.length, 1);
    gate.complete();
    await tester.pumpAndSettle();
    final saved = ref.read(foodWasteProvider).requireValue.single;
    await expectLater(
      ref
          .read(pantryWasteActionsProvider)
          .removeSavedQuantity(PantryWasteSource('alice', stock()), saved),
      throwsStateError,
    );
    expect(session.pantry.items['alice']!.single.quantity, 2);
  });
  testWidgets(
    'narrow large-text multiple suggestions and form animations settle',
    (tester) async {
      session.pantry.seed(
        'alice',
        stock(
          name: 'A very long homemade milk product with a descriptive name',
          quantity: 100,
        ),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'two', name: 'Another long Pantry item name'),
      );
      await open(tester, size: const Size(320, 700), scale: 2);
      await prefill(tester);
      expect(tester.takeException(), isNull);
      await save(tester);
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Cancel'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced-motion setting still leaves all actions usable', (
    tester,
  ) async {
    await open(tester, reducedMotion: true);
    await tap(tester, find.text('This Week'));
    expect(find.text('No waste recorded this week'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'optional linkage round-trips and manual six-field documents remain valid',
    () async {
      final linked = PantryWasteSource('alice', stock()).draft(wasteTestNow);
      expect(
        FoodWasteRecord.fromMap(
          'id',
          linked.toMap(),
        ).copyWith(quantity: 1).sourcePantryItemId,
        'milk',
      );
      expect(draft().toMap().length, 6);
      expect(
        PantryWasteSource(
          'alice',
          stock().copyWith(price: double.nan),
        ).draft(wasteTestNow).estimatedValue,
        0,
      );
      await session.changes.close();
    },
  );
}
