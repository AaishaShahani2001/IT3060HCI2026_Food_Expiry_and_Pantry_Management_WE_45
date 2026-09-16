import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/screens/add_shopping_item_screen.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/screens/shopping_list_screen.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_firestore.dart';

void main() {
  late ShoppingTestSession session;

  setUp(() {
    session = ShoppingTestSession();
  });
  tearDown(() => session.changes.close());

  Future<void> openScreen(
    WidgetTester tester, {
    bool seed = true,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (seed) {
      session.store.seed('alice', 'milk', 'Milk');
      session.store.seed('alice', 'bread', 'Bread', purchased: true);
      session.store.seed('alice', 'rice', 'Rice');
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ShoppingListScreen(),
        ),
        GoRoute(
          path: '/shopping/add',
          builder: (context, state) =>
              AddShoppingItemScreen(initialItem: state.extra as ShoppingItem?),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListRepositoryProvider.overrideWithValue(session.repository),
          shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  List<ShoppingItem> visibleState(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(ShoppingListScreen)),
      ).read(shoppingListProvider).requireValue;

  Future<void> selectMilk(WidgetTester tester) async {
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('long press and tap selection never change purchased state', (
    tester,
  ) async {
    await openScreen(tester);
    final before = visibleState(
      tester,
    ).map((item) => item.isPurchased).toList();
    await selectMilk(tester);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(visibleState(tester).map((item) => item.isPurchased), before);
    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping List'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
  });

  testWidgets(
    'Select All, Deselect All and cancel confirmation preserve data',
    (tester) async {
      await openScreen(tester);
      await selectMilk(tester);
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      await tester.tap(find.text('Deselect All'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete selected items'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all items?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      expect(session.store.commitCalls, 0);
      expect(visibleState(tester).length, 3);
    },
  );

  testWidgets(
    'confirmed multi-delete persists and returns to the empty state',
    (tester) async {
      await openScreen(tester);
      session.store.seed('bob', 'private', 'Bob private');
      await selectMilk(tester);
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete selected items'));
      await tester.pumpAndSettle();
      await confirmDelete(tester);
      expect(find.text('Your shopping list is empty'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
      expect(find.text('Shopping List'), findsOneWidget);
      expect(session.store.committedBatches.single.length, 3);
      expect(
        session.store.documents.containsKey('users/bob/shopping_items/private'),
        isTrue,
      );
      await tester.tap(find.byTooltip('Reload shopping list'));
      await tester.pumpAndSettle();
      expect(find.text('Your shopping list is empty'), findsOneWidget);
    },
  );

  testWidgets(
    'subset deletion uses count confirmation and keeps unselected item',
    (tester) async {
      await openScreen(tester);
      await selectMilk(tester);
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete selected items'));
      await tester.pumpAndSettle();
      expect(
        find.text('Are you sure you want to delete 2 selected items?'),
        findsOneWidget,
      );
      await confirmDelete(tester);
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Bread'), findsNothing);
      expect(find.text('Rice'), findsOneWidget);
    },
  );

  testWidgets(
    'single delete uses confirmation and the same persistent delete path',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.byTooltip('Delete Milk'));
      await tester.pumpAndSettle();
      expect(
        find.text('Are you sure you want to delete this item?'),
        findsOneWidget,
      );
      expect(session.store.commitCalls, 0);
      await confirmDelete(tester);
      expect(find.text('Milk'), findsNothing);
      expect(session.store.committedBatches.single, [
        'users/alice/shopping_items/milk',
      ]);
    },
  );

  testWidgets(
    'delete failure displays exact permission-denied and retains selection/data',
    (tester) async {
      await openScreen(tester);
      session.store.deleteError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Test denial',
      );
      await selectMilk(tester);
      await tester.tap(find.byTooltip('Delete selected items'));
      await tester.pumpAndSettle();
      await confirmDelete(tester);
      expect(
        find.textContaining('Firestore permission-denied: Test denial'),
        findsOneWidget,
      );
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(visibleState(tester).length, 3);
      expect(session.store.documents.length, 3);
    },
  );

  testWidgets(
    'pending delete keeps items visible and disables repeated delete',
    (tester) async {
      await openScreen(tester);
      final gate = Completer<void>();
      session.store.deleteGate = gate.future;
      await selectMilk(tester);
      await tester.tap(find.byTooltip('Delete selected items'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Milk'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Delete selected items',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(session.store.commitCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);
    },
  );

  testWidgets('read loading, failure and retry are visible', (tester) async {
    final gate = Completer<void>();
    session.store.readGate = gate.future;
    await openScreen(tester, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    session.store.readError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Test read denial',
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Test read denial'), findsOneWidget);
    session.store.readError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets(
    'account change hides old items while new account loads and clears selection',
    (tester) async {
      await openScreen(tester);
      await selectMilk(tester);
      session.store.seed('bob', 'private', 'Bob item');
      final gate = Completer<void>();
      session.store.readGate = gate.future;
      session.changeUser('bob');
      await tester.pump();
      await tester.pump();
      expect(find.text('Milk'), findsNothing);
      expect(find.text('1 selected'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bob item'), findsOneWidget);
      session.changeUser(null);
      await tester.pumpAndSettle();
      expect(find.text('Bob item'), findsNothing);
      expect(
        find.text('Please sign in to use your shopping list.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'account switch during confirmation cannot delete either account',
    (tester) async {
      await openScreen(tester);
      await selectMilk(tester);
      await tester.tap(find.byTooltip('Delete selected items'));
      await tester.pumpAndSettle();
      session.changeUser('bob');
      await tester.pumpAndSettle();
      await confirmDelete(tester);
      expect(session.store.commitCalls, 0);
      expect(session.store.documents.length, 3);
    },
  );

  testWidgets(
    'add form preserves autocomplete, quick quantity, dropdown and custom save',
    (tester) async {
      await openScreen(tester, seed: false);
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      final name = find.byType(TextFormField).at(0);
      final quantity = find.byType(TextFormField).at(1);
      final milkSuggestion = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Milk'),
      );
      await tester.enterText(name, 'm');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Macaroni'),
        ),
        findsOneWidget,
      );
      await tester.enterText(name, 'MI');
      await tester.pumpAndSettle();
      expect(milkSuggestion, findsOneWidget);
      expect(find.text('Mango'), findsNothing);
      await tester.tap(milkSuggestion);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(name).controller!.text, 'Milk');
      await tester.tap(find.widgetWithText(ChoiceChip, '4'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(quantity).controller!.text, '4');
      await tester.tap(find.byTooltip('Show suggested quantities'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '3'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(quantity).controller!.text, '3');
      await tester.enterText(name, 'Sri Lankan Red Rice');
      await tester.enterText(quantity, '9');
      await tester.tap(find.text('Save Item'));
      await tester.pumpAndSettle();
      expect(find.text('Sri Lankan Red Rice'), findsOneWidget);
      expect(find.text('Quantity: 9'), findsOneWidget);
      expect(session.store.addCalls, 1);
      expect(session.store.documents.values.single['quantity'], 9);
      await tester.tap(find.byTooltip('Reload shopping list'));
      await tester.pumpAndSettle();
      expect(find.text('Sri Lankan Red Rice'), findsOneWidget);
    },
  );

  testWidgets('edit prefill and purchased checkbox remain local-only', (
    tester,
  ) async {
    await openScreen(tester);
    await tester.tap(find.byTooltip('Edit Bread'));
    await tester.pumpAndSettle();
    final name = find.byType(TextFormField).at(0);
    final quantity = find.byType(TextFormField).at(1);
    expect(tester.widget<TextFormField>(name).controller!.text, 'Bread');
    expect(tester.widget<TextFormField>(quantity).controller!.text, '2');
    await tester.enterText(name, 'Fresh Bread');
    await tester.enterText(quantity, '5');
    await tester.tap(find.text('Update Item'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh Bread'), findsOneWidget);
    final bread = visibleState(tester).firstWhere((item) => item.id == 'bread');
    expect(bread.isPurchased, isTrue);
    expect(session.store.addCalls, 0);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(
      visibleState(tester).firstWhere((item) => item.id == 'milk').isPurchased,
      isTrue,
    );
    await tester.tap(find.byTooltip('Reload shopping list'));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Fresh Bread'), findsNothing);
    expect(
      visibleState(tester).firstWhere((item) => item.id == 'milk').isPurchased,
      isFalse,
    );
  });

  testWidgets('empty name and out-of-range quantity cannot be submitted', (
    tester,
  ) async {
    await openScreen(tester, seed: false);
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();
    expect(find.byType(AddShoppingItemScreen), findsOneWidget);
    expect(session.store.addCalls, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'Custom food');
    for (final quantity in ['0', '101']) {
      await tester.enterText(find.byType(TextFormField).at(1), quantity);
      await tester.tap(find.text('Save Item'));
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(session.store.addCalls, 0);
    }
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();
    expect(find.text('Custom food'), findsOneWidget);
    expect(session.store.addCalls, 1);
  });

  testWidgets('failed save reports error and Retry saves the same draft once', (
    tester,
  ) async {
    await openScreen(tester, seed: false);
    session.store.addError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Test save denial',
    );
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Custom food');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test save denial'), findsOneWidget);
    expect(session.store.documents, isEmpty);
    expect(find.text('Your shopping list is empty'), findsOneWidget);
    session.store.addError = null;
    await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Custom food'), findsOneWidget);
    expect(session.store.documents.length, 1);
    expect(visibleState(tester).length, 1);
  });

  testWidgets(
    'switching accounts while form is open cannot save its old draft',
    (tester) async {
      await openScreen(tester, seed: false);
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Alice draft');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      session.changeUser('bob');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Item'));
      await tester.pumpAndSettle();
      expect(session.store.addCalls, 0);
      expect(find.text('Alice draft'), findsNothing);
    },
  );

  testWidgets('cancel single delete leaves the document and item untouched', (
    tester,
  ) async {
    await openScreen(tester);
    await tester.tap(find.byTooltip('Delete Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(session.store.commitCalls, 0);
    expect(session.store.documents.length, 3);
  });
}
