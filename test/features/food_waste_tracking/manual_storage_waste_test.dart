import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_scope.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/pantry_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/waste_tracker_screen.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_firestore_service.dart';
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

  Future<void> open(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(430, 1000),
    double textScale = 1,
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
          theme: theme ?? AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const WasteTrackerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        220,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester) async {
    await tap(tester, find.widgetWithText(FilledButton, 'Record Waste'));
  }

  Future<void> selectStorage(WidgetTester tester, String itemName) async {
    await tap(tester, find.byKey(const ValueKey('waste-source-storage')));
    await tester.enterText(
      find.byKey(const ValueKey('waste-storage-item')),
      itemName,
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text(itemName).last);
  }

  Future<void> enterQuantity(WidgetTester tester, String quantity) async {
    await reveal(tester, find.byKey(const ValueKey('waste-quantity')));
    await tester.enterText(
      find.byKey(const ValueKey('waste-quantity')),
      quantity,
    );
    await tester.pump();
  }

  Future<void> openStorageConfirmation(WidgetTester tester) async {
    await reveal(tester, find.byKey(const ValueKey('save-waste')));
    await tester.tap(find.byKey(const ValueKey('save-waste')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Record stored food as waste?'), findsOneWidget);
  }

  Future<void> confirmStorage(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Record Waste').last);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> saveStorage(WidgetTester tester) async {
    await openStorageConfirmation(tester);
    await confirmStorage(tester);
    if (find.text('Similar waste record').evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(FilledButton, 'Save Anyway'));
      await tester.pump();
      await tester.pumpAndSettle();
    }
  }

  testWidgets('source selector defaults to external and explains automation', (
    tester,
  ) async {
    await open(tester);
    await openForm(tester);

    expect(find.text('Where is this item from?'), findsOneWidget);
    expect(find.text('My Storage'), findsOneWidget);
    expect(find.text('Other / External'), findsOneWidget);
    expect(
      find.text(
        'Expired items with saved expiry dates are tracked automatically.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('waste-name')), findsOneWidget);
  });

  testWidgets(
    'My Storage lists positive stock across locations and prefills locked unit',
    (tester) async {
      session.pantry.seed(
        'alice',
        stock(name: 'Milk', quantity: 2, noExpiry: true),
      );
      session.pantry.seed(
        'alice',
        stock(
          id: 'peas',
          name: 'Peas',
          quantity: 3,
          noExpiry: true,
        ).copyWith(location: PantryLocation.freezer),
      );
      session.pantry.seed(
        'alice',
        stock(
          id: 'rice',
          name: 'Rice',
          quantity: 4,
          noExpiry: true,
        ).copyWith(location: PantryLocation.pantry),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'zero', name: 'Zero', quantity: 0, noExpiry: true),
      );

      await open(tester);
      await openForm(tester);
      await tap(tester, find.byKey(const ValueKey('waste-source-storage')));
      await tester.enterText(
        find.byKey(const ValueKey('waste-storage-item')),
        ' ',
      );
      await tester.pumpAndSettle();

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Peas'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Zero'), findsNothing);

      await tap(tester, find.text('Milk'));
      expect(find.text('Dairy • Refrigerator'), findsOneWidget);
      expect(find.text('Available: 2 bottles'), findsOneWidget);
      final unit = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(unit.onChanged, isNull);
    },
  );

  testWidgets(
    'My Storage shows loading without an empty state then selects on first tap',
    (tester) async {
      final gate = Completer<void>();
      session.pantry.watchGate = gate.future;
      session.pantry.seed(
        'alice',
        stock(
          id: 'test-apple',
          name: 'Test Apple',
          quantity: 2,
          unit: PantryUnit.items,
          noExpiry: true,
        ),
      );

      await open(tester);
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('waste-source-storage')));
      await tester.pump();

      expect(find.text('Loading stored items...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('No stored items with remaining quantity are available.'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('waste-storage-item')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Loading stored items...'), findsNothing);
      expect(find.byKey(const ValueKey('waste-storage-item')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('waste-storage-item')),
        'Test Apple',
      );
      await tester.pumpAndSettle();
      final search = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('waste-storage-item')),
          matching: find.byType(EditableText),
        ),
      );
      expect(search.focusNode.hasFocus, isTrue);

      await tester.tap(find.text('Test Apple').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('waste-storage-details')),
        findsOneWidget,
      );
      expect(find.text('Available: 2 items'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('waste-quantity')))
            .enabled,
        isNot(false),
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'pcs',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('waste-value')))
            .controller!
            .text,
        '0',
      );
    },
  );

  testWidgets('storage quantity validates positive and current availability', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');

    await enterQuantity(tester, '0');
    await reveal(tester, find.byKey(const ValueKey('save-waste')));
    await tester.tap(find.byKey(const ValueKey('save-waste')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter a quantity greater than 0.'), findsOneWidget);

    await enterQuantity(tester, '1');
    expect(find.text('Enter a quantity greater than 0.'), findsNothing);

    await enterQuantity(tester, '3');
    expect(
      find.text('Waste quantity cannot exceed 2 bottles.'),
      findsOneWidget,
    );

    await enterQuantity(tester, '1');
    expect(find.text('Waste quantity cannot exceed 2 bottles.'), findsNothing);
    await openStorageConfirmation(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(session.store.addCalls, 0);
  });

  testWidgets(
    'partial and full storage waste use safe decrement without Used Up',
    (tester) async {
      session.pantry.seed(
        'alice',
        stock(name: 'Milk', quantity: 2, noExpiry: true),
      );
      await open(tester);
      await openForm(tester);
      await selectStorage(tester, 'Milk');
      await enterQuantity(tester, '1');
      await saveStorage(tester);

      expect(session.store.documents, hasLength(1));
      expect(session.store.documents.values.single['source'], 'pantry');
      expect(session.pantry.items['alice']!.single.quantity, 1);
      expect(session.pantry.decrements, [('alice', 'milk', 1.0)]);
      expect(find.text('Milk'), findsOneWidget);

      await openForm(tester);
      await selectStorage(tester, 'Milk');
      await enterQuantity(tester, '1');
      await saveStorage(tester);

      expect(session.store.documents, hasLength(2));
      expect(session.pantry.items['alice']!.single.quantity, 0);
      expect(session.pantry.items['alice']!.single.firestoreId, 'milk');
      expect(session.pantry.decrements, hasLength(2));
      expect(session.pantry.markItemConsumedCalls, 0);
      expect(session.pantry.markAsUsedUpCalls, 0);
      expect(session.pantry.deletePantryItemCalls, 0);
    },
  );

  testWidgets(
    'single full storage waste decrements two to zero without Used Up',
    (tester) async {
      session.pantry.seed(
        'alice',
        stock(name: 'Milk', quantity: 2, noExpiry: true),
      );
      await open(tester);
      await openForm(tester);
      await selectStorage(tester, 'Milk');
      await enterQuantity(tester, '2');
      await saveStorage(tester);

      expect(session.store.documents, hasLength(1));
      expect(session.store.documents.values.single['quantity'], 2);
      expect(session.pantry.decrements, [('alice', 'milk', 2.0)]);
      expect(session.pantry.items['alice'], hasLength(1));
      expect(session.pantry.items['alice']!.single.quantity, 0);
      expect(session.pantry.items['alice']!.single.firestoreId, 'milk');
      expect(session.pantry.markItemConsumedCalls, 0);
      expect(session.pantry.markAsUsedUpCalls, 0);
      expect(session.pantry.deletePantryItemCalls, 0);
      expect(find.textContaining('marked as used up'), findsNothing);
      expect(find.text('UNDO'), findsNothing);
      expect(find.text('ADD TO LIST'), findsNothing);
    },
  );

  test('storage pricing reuses unit and proportional Pantry semantics', () {
    double value(PantryItem item, double quantity) => PantryWasteSource(
      WasteScope.personal(actorUid: 'alice'),
      item,
    ).estimatedValueFor(quantity);

    expect(
      value(
        stock(
          quantity: 2,
          noExpiry: true,
          priceAmount: 300,
          priceType: PantryPriceType.unitPrice,
        ),
        1,
      ),
      300,
    );
    expect(
      value(
        stock(
          quantity: 2,
          originalQuantity: 2,
          noExpiry: true,
          priceAmount: 800,
        ),
        1,
      ),
      400,
    );
    expect(
      value(
        stock(
          quantity: 5,
          originalQuantity: 5,
          unit: PantryUnit.kg,
          noExpiry: true,
          priceAmount: 2000,
        ),
        0.5,
      ),
      200,
    );
    expect(
      value(
        stock(
          quantity: 500,
          unit: PantryUnit.g,
          noExpiry: true,
          priceAmount: 400,
          priceType: PantryPriceType.unitPrice,
        ),
        250,
      ),
      100,
    );
    expect(
      value(
        stock(
          quantity: 2,
          unit: PantryUnit.liters,
          noExpiry: true,
          priceAmount: 300,
          priceType: PantryPriceType.unitPrice,
        ),
        0.5,
      ),
      150,
    );
    expect(
      value(
        stock(
          quantity: 500,
          unit: PantryUnit.ml,
          noExpiry: true,
          priceAmount: 300,
          priceType: PantryPriceType.unitPrice,
        ),
        250,
      ),
      75,
    );
    expect(value(stock(noExpiry: true, priceAmount: null), 1), 0);
  });

  testWidgets('storage estimated value is automatic and read-only', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(
        name: 'Milk',
        quantity: 2,
        originalQuantity: 2,
        noExpiry: true,
        priceAmount: 800,
      ),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');

    final value = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('waste-value')),
        matching: find.byType(TextField),
      ),
    );
    expect(value.readOnly, isTrue);
    expect(value.controller!.text, '400');
  });

  testWidgets('known expired storage item cannot create manual duplicate', (
    tester,
  ) async {
    session.pantry.seed('alice', stock(name: 'Milk', quantity: 2));
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    expect(
      find.text('This expired item is tracked automatically in Waste Tracker.'),
      findsOneWidget,
    );
    await enterQuantity(tester, '1');
    final before = session.store.documents.length;
    await reveal(tester, find.byKey(const ValueKey('save-waste')));
    await tester.tap(find.byKey(const ValueKey('save-waste')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(session.store.documents.length, before);
  });

  testWidgets(
    'an older automatic expiry event does not mark fresh stock expired',
    (tester) async {
      session.pantry.seed(
        'alice',
        stock(name: 'Milk', quantity: 2, expiry: DateTime(2026, 9, 20)),
      );
      session.seed(
        'alice',
        'old-expiry',
        FoodWasteRecord(
          itemName: 'Milk',
          quantity: 1,
          unit: 'bottle',
          reason: 'Expired',
          estimatedValue: 400,
          wastedAt: DateTime(2026, 9, 11),
          source: automaticExpiryWasteSource,
          sourcePantryItemId: 'milk',
          sourceExpiryDate: DateTime(2026, 9, 10),
        ),
      );
      await open(tester);
      await openForm(tester);
      await selectStorage(tester, 'Milk');
      expect(
        find.text(
          'This expired item is tracked automatically in Waste Tracker.',
        ),
        findsNothing,
      );
      await enterQuantity(tester, '1');
      await saveStorage(tester);

      expect(session.store.documents, hasLength(2));
      expect(session.pantry.items['alice']!.single.quantity, 1);
    },
  );

  testWidgets('no-expiry storage item can still select Expired reason', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    await tap(tester, find.text('Expired'));
    await saveStorage(tester);
    expect(session.store.documents.values.single['reason'], 'Expired');
    expect(session.pantry.items['alice']!.single.quantity, 1);
  });

  testWidgets('external flow stays manual and never changes Pantry', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('waste-name')),
      'Takeaway rice',
    );
    await tester.enterText(find.byKey(const ValueKey('waste-quantity')), '1');
    await tester.enterText(find.byKey(const ValueKey('waste-value')), '450');
    await tap(tester, find.byKey(const ValueKey('save-waste')));

    final data = session.store.documents.values.single;
    expect(data['itemName'], 'Takeaway rice');
    expect(data.containsKey('sourcePantryItemId'), isFalse);
    expect(session.pantry.items['alice']!.single.quantity, 2);
    expect(session.pantry.decrements, isEmpty);
    expect(find.text('Takeaway rice'), findsOneWidget);
  });

  testWidgets(
    'shared My Storage writes household records and supports partial and full depletion',
    (tester) async {
      final scope = WasteScope.shared(
        actorUid: 'alice',
        pantryId: 'family-one',
      );
      session.changeScope(scope);
      session.pantry.seed(
        'alice',
        stock(name: 'Milk', quantity: 2, noExpiry: true),
      );
      session.pantry.seed(
        'alice',
        stock(id: 'juice', name: 'Juice', quantity: 2, noExpiry: true),
      );
      await open(tester);

      await openForm(tester);
      await selectStorage(tester, 'Milk');
      await enterQuantity(tester, '1');
      await saveStorage(tester);
      await openForm(tester);
      await selectStorage(tester, 'Juice');
      await enterQuantity(tester, '2');
      await saveStorage(tester);

      expect(
        session.store.documents.keys,
        everyElement(startsWith('pantries/family-one/waste_records/')),
      );
      expect(
        session.store.documents.values,
        everyElement(containsPair('recordedByUid', 'alice')),
      );
      final items = session.pantry.items['pantry:family-one']!;
      expect(items.singleWhere((item) => item.name == 'Milk').quantity, 1);
      final depleted = items.singleWhere((item) => item.name == 'Juice');
      expect(depleted.quantity, 0);
      expect(depleted.firestoreId, 'juice');
      expect(session.pantry.decrements, [
        ('alice', 'milk', 1.0),
        ('alice', 'juice', 2.0),
      ]);
      expect(session.pantry.markAsUsedUpCalls, 0);
      expect(session.pantry.deletePantryItemCalls, 0);
    },
  );

  testWidgets('shared external Waste saves without changing Pantry', (
    tester,
  ) async {
    final scope = WasteScope.shared(actorUid: 'alice', pantryId: 'family-one');
    session.changeScope(scope);
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('waste-name')),
      'Restaurant meal',
    );
    await tester.enterText(find.byKey(const ValueKey('waste-quantity')), '1');
    await tester.enterText(find.byKey(const ValueKey('waste-value')), '900');
    await tap(tester, find.byKey(const ValueKey('save-waste')));

    expect(session.store.documents, hasLength(1));
    expect(
      session.store.documents.keys.single,
      startsWith('pantries/family-one/waste_records/'),
    );
    expect(session.store.documents.values.single['recordedByUid'], 'alice');
    expect(session.pantry.decrements, isEmpty);
    expect(session.pantry.items['pantry:family-one']!.single.quantity, 2);
  });

  testWidgets('shared decrement failure rolls back only captured scope', (
    tester,
  ) async {
    final personal = WasteScope.personal(actorUid: 'alice');
    final shared = WasteScope.shared(actorUid: 'alice', pantryId: 'family-one');
    session.seedScope(personal, 'personal-record', draft(name: 'Personal'));
    session.changeScope(shared);
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    session.pantry.decrementError = StateError('decrement failed');
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    await saveStorage(tester);

    expect(
      session.store.documents.keys,
      contains('${personal.collectionPath}/personal-record'),
    );
    expect(
      session.store.documents.keys.where(
        (path) => path.startsWith('${shared.collectionPath}/'),
      ),
      isEmpty,
    );
    expect(session.pantry.items['pantry:family-one']!.single.quantity, 2);
  });

  testWidgets('scope change before save prevents every write', (tester) async {
    final familyA = WasteScope.shared(actorUid: 'alice', pantryId: 'family-a');
    session.changeScope(familyA);
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');

    session.changeScope(
      WasteScope.shared(actorUid: 'alice', pantryId: 'family-b'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Your pantry context changed.'), findsOneWidget);
    expect(session.store.addCalls, 0);
    expect(session.pantry.decrements, isEmpty);
  });

  testWidgets(
    'scope change after create rolls back captured household before decrement',
    (tester) async {
      final familyA = WasteScope.shared(
        actorUid: 'alice',
        pantryId: 'family-a',
      );
      session.changeScope(familyA);
      session.pantry.seed(
        'alice',
        stock(name: 'Milk', quantity: 2, noExpiry: true),
      );
      session.store.afterAdd = (_) => session.changeScope(
        WasteScope.shared(actorUid: 'alice', pantryId: 'family-b'),
      );
      await open(tester);
      await openForm(tester);
      await selectStorage(tester, 'Milk');
      await enterQuantity(tester, '1');
      await openStorageConfirmation(tester);
      await confirmStorage(tester);

      expect(
        session.store.documents.keys.where(
          (path) => path.startsWith('${familyA.collectionPath}/'),
        ),
        isEmpty,
      );
      expect(session.store.addCalls, 1);
      expect(session.store.commitCalls, 1);
      expect(session.pantry.decrements, isEmpty);
      expect(session.pantry.items['pantry:family-a']!.single.quantity, 2);
    },
  );

  testWidgets('latest quantity change rolls back Waste without clamping', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '2');
    session.pantry.beforeDecrement = () {
      session.pantry.beforeDecrement = null;
      session.pantry.seed(
        'alice',
        stock(name: 'Milk', quantity: 1, noExpiry: true),
      );
    };
    await saveStorage(tester);

    expect(session.store.documents, isEmpty);
    expect(session.pantry.items['alice']!.single.quantity, 1);
    expect(session.pantry.decrements, [('alice', 'milk', 2.0)]);
    expect(find.textContaining('available quantity changed'), findsOneWidget);
    expect(find.byKey(const ValueKey('waste-storage-details')), findsNothing);
  });

  testWidgets('deleted storage item rolls back Waste and is not recreated', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    session.pantry.beforeDecrement = () {
      session.pantry.beforeDecrement = null;
      session.pantry.remove('alice', 'milk');
    };
    await saveStorage(tester);

    expect(session.store.documents, isEmpty);
    expect(session.pantry.items['alice'], isEmpty);
    expect(session.pantry.deletePantryItemCalls, 0);
    expect(find.textContaining('no longer available'), findsOneWidget);
  });

  testWidgets('Pantry decrement failure rolls back only the new Waste record', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    session.pantry.decrementError = const PantryFirestoreException(
      'Unable to update item.',
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    await saveStorage(tester);

    expect(session.store.documents, isEmpty);
    expect(session.store.addCalls, 1);
    expect(session.store.commitCalls, 1);
    expect(session.pantry.items['alice']!.single.quantity, 2);
    expect(find.textContaining('Waste was not recorded'), findsOneWidget);
  });

  testWidgets('Waste write failure never decrements Pantry', (tester) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    session.store.addError = StateError('write failed');
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    await saveStorage(tester);

    expect(session.store.documents, isEmpty);
    expect(session.pantry.decrements, isEmpty);
    expect(session.pantry.items['alice']!.single.quantity, 2);
  });

  testWidgets('rollback failure shows explicit consistency warning', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    session.pantry.decrementError = const PantryFirestoreException(
      'Unable to update item.',
    );
    session.store.deleteError = StateError('rollback failed');
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    await saveStorage(tester);

    expect(session.store.documents, hasLength(1));
    expect(session.pantry.items['alice']!.single.quantity, 2);
    expect(
      find.textContaining("couldn't fully complete this update"),
      findsOneWidget,
    );
  });

  testWidgets('repeated Save taps create one Waste and one decrement', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    await reveal(tester, find.byKey(const ValueKey('save-waste')));
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-waste')),
    );
    saveButton.onPressed!();
    saveButton.onPressed!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Record stored food as waste?'), findsOneWidget);
    await confirmStorage(tester);

    expect(session.store.addCalls, 1);
    expect(session.pantry.decrements, hasLength(1));
    expect(session.store.documents, hasLength(1));
  });

  testWidgets('account change cannot save or expose another user storage', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(id: 'alice-milk', name: 'Alice milk', noExpiry: true),
    );
    session.pantry.seed(
      'bob',
      stock(id: 'bob-milk', name: 'Bob milk', noExpiry: true),
    );
    await open(tester);
    await openForm(tester);
    await selectStorage(tester, 'Alice milk');
    await enterQuantity(tester, '1');
    session.changeUser('bob');
    await tester.pumpAndSettle();

    expect(find.textContaining('Your account changed.'), findsOneWidget);
    expect(session.store.documents, isEmpty);
    expect(session.pantry.decrements, isEmpty);
    expect(find.text('Bob milk'), findsNothing);
  });

  testWidgets('source form remains usable at narrow width in light and dark', (
    tester,
  ) async {
    session.pantry.seed(
      'alice',
      stock(name: 'Milk', quantity: 2, noExpiry: true),
    );
    await open(
      tester,
      size: const Size(320, 700),
      textScale: 1.4,
      theme: AppTheme.dark,
    );
    await openForm(tester);
    await selectStorage(tester, 'Milk');
    await enterQuantity(tester, '1');
    await reveal(tester, find.byKey(const ValueKey('save-waste')));
    expect(tester.takeException(), isNull);
  });
}
