import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/core/providers/theme_mode_provider.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_shell.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/screens/pantry_item_form_screen.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/low_stock_suggestion_settings_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_pantry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/screens/add_shopping_item_screen.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/screens/shopping_list_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_firestore.dart';

PantryItem lowStockItem(
  String id,
  String name, {
  double quantity = 1,
  PantryUnit unit = PantryUnit.items,
  PantryCategory category = PantryCategory.other,
}) => PantryItem(
  id: id,
  firestoreId: id,
  name: name,
  category: category,
  location: PantryLocation.pantry,
  quantity: quantity,
  unit: unit,
);

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
    Size size = const Size(430, 900),
    double textScale = 1,
    bool dark = false,
    List<PantryItem> pantryItems = const [],
    SharedPreferences? preferences,
  }) async {
    tester.view.physicalSize = size;
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
          shoppingPantryItemsProvider.overrideWithValue(AsyncData(pantryItems)),
          if (preferences != null)
            sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark : AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              accessibleNavigation: false,
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  List<ShoppingItem> visibleState(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(ShoppingListScreen, skipOffstage: false)),
      ).read(shoppingListProvider).requireValue;

  Future<void> pullRefresh(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
  }

  Future<void> selectMilk(WidgetTester tester) async {
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  Future<void> rowAction(
    WidgetTester tester,
    String name,
    String action,
  ) async {
    await tester.tap(find.byTooltip('Actions for $name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
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
      expect(find.text('Delete all selected items?'), findsOneWidget);
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
      expect(find.byTooltip('Add shopping item'), findsOneWidget);
      expect(find.text('Shopping List'), findsOneWidget);
      expect(session.store.committedBatches.single.length, 3);
      expect(
        session.store.documents.containsKey('users/bob/shopping_items/private'),
        isTrue,
      );
      await pullRefresh(tester);
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
      await rowAction(tester, 'Milk', 'Delete item');
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
    'delete failure gives safe access feedback and retains selection/data',
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
      expect(find.textContaining("You don't have permission"), findsOneWidget);
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
    expect(find.textContaining("You don't have permission"), findsOneWidget);
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
      await tester.tap(find.byTooltip('Add shopping item'));
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
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(find.text('Sri Lankan Red Rice'), findsOneWidget);
      expect(visibleState(tester).single.quantity, 9);
      expect(find.text('9 pcs'), findsOneWidget);
      expect(session.store.addCalls, 1);
      expect(session.store.documents.values.single['quantity'], 9);
      await pullRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Sri Lankan Red Rice'), findsOneWidget);
    },
  );

  testWidgets('edit prefill and purchased checkbox persist after refresh', (
    tester,
  ) async {
    await openScreen(tester);
    await rowAction(tester, 'Bread', 'Edit item');
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
    await pullRefresh(tester);
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsNothing);
    expect(find.text('Fresh Bread'), findsOneWidget);
    expect(
      visibleState(tester).firstWhere((item) => item.id == 'milk').isPurchased,
      isTrue,
    );
  });

  testWidgets('empty name and out-of-range quantity cannot be submitted', (
    tester,
  ) async {
    await openScreen(tester, seed: false);
    await tester.tap(find.byTooltip('Add shopping item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    expect(find.byType(AddShoppingItemScreen), findsOneWidget);
    expect(session.store.addCalls, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'Custom food');
    for (final quantity in ['0', '101']) {
      await tester.enterText(find.byType(TextFormField).at(1), quantity);
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(session.store.addCalls, 0);
    }
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    expect(find.text('Custom food'), findsOneWidget);
    expect(session.store.addCalls, 1);
  });

  testWidgets(
    'failed save retains the form and resubmitting saves the same draft once',
    (tester) async {
      await openScreen(tester, seed: false);
      session.store.addError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Test save denial',
      );
      await tester.tap(find.byTooltip('Add shopping item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Custom food');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(find.textContaining("You don't have permission"), findsOneWidget);
      expect(session.store.documents, isEmpty);
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Custom food',
      );
      session.store.addError = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Add Item'));
      await tester.pumpAndSettle();
      expect(find.text('Custom food'), findsOneWidget);
      expect(session.store.documents.length, 1);
      expect(visibleState(tester).length, 1);
    },
  );

  testWidgets(
    'switching accounts while form is open cannot save its old draft',
    (tester) async {
      await openScreen(tester, seed: false);
      await tester.tap(find.byTooltip('Add shopping item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Alice draft');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      session.changeUser('bob');
      await tester.pumpAndSettle();
      expect(find.textContaining('Your account changed.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(session.store.addCalls, 0);
      expect(find.text('Alice draft'), findsNothing);
    },
  );

  testWidgets('cancel single delete leaves the document and item untouched', (
    tester,
  ) async {
    await openScreen(tester);
    await rowAction(tester, 'Milk', 'Delete item');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(session.store.commitCalls, 0);
    expect(session.store.documents.length, 3);
  });

  testWidgets(
    'category delete uses the full category despite filters and preserves Pantry',
    (tester) async {
      session.store.seed('alice', 'apple', 'Apple');
      session.store.seed('alice', 'banana', 'Banana');
      session.store.seed('alice', 'orange', 'Orange', purchased: true);
      session.store.seed('alice', 'milk', 'Milk');
      final pantryItems = [
        lowStockItem('pantry-apple', 'Apple', category: PantryCategory.fruits),
        lowStockItem(
          'pantry-orange',
          'Orange',
          category: PantryCategory.fruits,
        ),
      ];
      await openScreen(tester, seed: false, pantryItems: pantryItems);

      final categorySemantics = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Collapse Fruits category')),
      );
      expect(
        categorySemantics.getSemanticsData().customSemanticsActionIds,
        isNotEmpty,
      );

      await tester.longPress(find.text('Fruits (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all items in Fruits'), findsOneWidget);
      await tester.tap(find.text('Delete all items in Fruits'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Fruits items?'), findsOneWidget);
      expect(
        find.text(
          'This will remove all 3 items in the Fruits category from your Shopping List.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TO BUY (3)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'apple',
      );
      await tester.pumpAndSettle();
      expect(find.text('Fruits (1)'), findsOneWidget);

      await tester.longPress(find.text('Fruits (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all items in Fruits'), findsOneWidget);
      await tester.tap(find.text('Delete all items in Fruits'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Fruits items?'), findsOneWidget);
      expect(
        find.text(
          'This will remove all 3 items in the Fruits category from your Shopping List.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.store.commitCalls, 0);
      expect(session.store.documents.length, 4);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BOUGHT (1)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'orange',
      );
      await tester.pumpAndSettle();
      expect(find.text('Fruits (1)'), findsOneWidget);
      await tester.longPress(find.text('Fruits (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete all items in Fruits'));
      await tester.pumpAndSettle();
      await confirmDelete(tester);

      expect(session.store.documents.keys, ['users/alice/shopping_items/milk']);
      expect(find.text('Fruits (1)'), findsNothing);
      expect(find.text('3 items removed from Fruits.'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShoppingListScreen)),
      );
      expect(
        container.read(shoppingPantryItemsProvider).requireValue,
        same(pantryItems),
      );
    },
  );

  testWidgets(
    'collapsed category supports singular delete and resets stale expansion state',
    (tester) async {
      session.store.seed('alice', 'milk', 'Milk');
      await openScreen(tester, seed: false, dark: true);
      await tester.tap(find.text('Dairy (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Expand Dairy category')),
        findsOneWidget,
      );

      await tester.longPress(find.text('Dairy (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all items in Dairy'), findsOneWidget);
      await tester.tap(find.text('Delete all items in Dairy'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This will remove 1 item in the Dairy category from your Shopping List.',
        ),
        findsOneWidget,
      );
      await confirmDelete(tester);

      expect(session.store.documents, isEmpty);
      expect(find.text('1 item removed from Dairy.'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShoppingListScreen)),
      );
      expect(
        container
            .read(currentShoppingCategoryExpansionProvider)
            .containsKey('Dairy'),
        isFalse,
      );

      session.store.seed('alice', 'fresh-milk', 'Fresh Milk');
      await pullRefresh(tester);
      expect(find.text('Dairy (1)'), findsOneWidget);
      expect(find.text('Fresh Milk'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Collapse Dairy category')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tabs use whole-list counts; search is trimmed and case insensitive',
    (tester) async {
      await openScreen(tester);
      expect(find.text('ALL (3)'), findsOneWidget);
      expect(find.text('TO BUY (2)'), findsOneWidget);
      expect(find.text('BOUGHT (1)'), findsOneWidget);
      await tester.tap(find.text('TO BUY (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        '  MIL  ',
      );
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Rice'), findsNothing);
      expect(find.text('ALL (3)'), findsOneWidget);
      expect(find.text('TO BUY (2)'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsOneWidget);
      await tester.tap(find.text('BOUGHT (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      expect(find.text('BOUGHT (0)'), findsOneWidget);
      expect(find.text('TO BUY (3)'), findsOneWidget);
      expect(find.text('No bought items yet'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
    },
  );

  testWidgets('catalogue groups collapse locally; unknown names use Other', (
    tester,
  ) async {
    session.store.seed('alice', 'custom', 'Homemade meal');
    await openScreen(tester);
    expect(find.text('Dairy (1)'), findsOneWidget);
    expect(find.text('Bakery (1)'), findsOneWidget);
    expect(find.text('Grains (1)'), findsOneWidget);
    expect(find.text('Other (1)'), findsOneWidget);
    await tester.tap(find.text('Dairy (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
    expect(find.text('ALL (4)'), findsOneWidget);
    await tester.tap(find.text('Dairy (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(session.store.addCalls, 0);
    expect(session.store.commitCalls, 0);
  });

  testWidgets(
    'category expansion is independent and survives filters search and refresh',
    (tester) async {
      session.store.seed('alice', 'apple', 'Apple');
      await openScreen(tester);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Collapse Dairy category')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Collapse Fruits category')),
        findsOneWidget,
      );

      await tester.tap(find.text('Dairy (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fruits (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Dairy (1)'), findsOneWidget);
      expect(find.text('Fruits (1)'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Apple'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Expand Dairy category')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Expand Fruits category')),
        findsOneWidget,
      );

      await tester.tap(find.text('Dairy (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);

      await tester.tap(find.text('BOUGHT (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Fruits (1)'), findsNothing);
      await tester.tap(find.text('ALL (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Fruits (1)'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'apple',
      );
      await tester.pumpAndSettle();
      expect(find.text('Fruits (1)'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Fruits (1)'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShoppingListScreen)),
      );
      container.invalidate(shoppingListProvider);
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
    },
  );

  testWidgets(
    'quantity controls persist 1-100 and preserve IDs and purchased state',
    (tester) async {
      session.store.seed('alice', 'milk', 'Milk', purchased: true);
      session.store.documents['users/alice/shopping_items/milk']!['quantity'] =
          1;
      await openScreen(tester, seed: false);
      IconButton button(String label) => tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == label,
        ),
      );
      expect(button('Decrease quantity of Milk').onPressed, isNull);
      await tester.tap(find.byTooltip('Increase quantity of Milk'));
      await tester.pumpAndSettle();
      expect(visibleState(tester).single.quantity, 2);
      expect(visibleState(tester).single.id, 'milk');
      expect(visibleState(tester).single.isPurchased, isTrue);
      expect(session.store.documents.values.single['quantity'], 2);
      await tester.tap(find.byTooltip('Decrease quantity of Milk'));
      await tester.pumpAndSettle();
      expect(visibleState(tester).single.quantity, 1);
      session.store.documents.values.single['quantity'] = 100;
      await pullRefresh(tester);
      await tester.pumpAndSettle();
      expect(visibleState(tester).single.quantity, 100);
      expect(button('Increase quantity of Milk').onPressed, isNull);
      await tester.tap(find.byTooltip('Decrease quantity of Milk'));
      await tester.pumpAndSettle();
      expect(visibleState(tester).single.quantity, 99);
      expect(session.store.addCalls, 0);
      expect(session.store.commitCalls, 0);
    },
  );

  testWidgets(
    'Select All only deletes filtered matches and locks search/tabs',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('TO BUY (2)'));
      await tester.pumpAndSettle();
      await selectMilk(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shopping-search')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'ALL (3)'),
            )
            .onPressed,
        isNull,
      );
      expect(find.byTooltip('Increase quantity of Milk'), findsNothing);
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete selected items'));
      await tester.pumpAndSettle();
      expect(
        find.text('Are you sure you want to delete 2 selected items?'),
        findsOneWidget,
      );
      await confirmDelete(tester);
      expect(session.store.documents.keys, [
        'users/alice/shopping_items/bread',
      ]);
      expect(find.text('ALL (1)'), findsOneWidget);
      expect(find.text('No items to buy'), findsOneWidget);
      await tester.tap(find.text('BOUGHT (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsOneWidget);
    },
  );

  testWidgets(
    'search plus opens the same add form and saved item clears filters',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('BOUGHT (1)'));
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'bread',
      );
      await tester.tap(find.byTooltip('Add shopping item'));
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Tomato');
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(find.text('ALL (4)'), findsOneWidget);
      expect(find.text('Tomato'), findsOneWidget);
      expect(find.text('Vegetables (1)'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shopping-search')))
            .controller!
            .text,
        isEmpty,
      );
      expect(session.store.addCalls, 1);
    },
  );

  testWidgets(
    'account switch resets query and isolates UI state; stale menu cannot delete',
    (tester) async {
      await openScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'milk',
      );
      await tester.tap(find.byTooltip('Actions for Milk'));
      await tester.pumpAndSettle();
      session.store.seed('bob', 'milk', 'Milk');
      session.changeUser('bob');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete item'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(session.store.commitCalls, 0);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shopping-search')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('ALL (1)'), findsOneWidget);
    },
  );

  testWidgets(
    'selection expands collapsed matching groups without changing purchases',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('Dairy (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);
      await tester.longPress(find.text('Bread'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      expect(
        visibleState(tester).where((item) => item.isPurchased).single.name,
        'Bread',
      );
      expect(session.store.commitCalls, 0);
      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Expand Dairy category')),
        findsOneWidget,
      );
    },
  );

  testWidgets('search with keyboard on a small phone does not overflow', (
    tester,
  ) async {
    await openScreen(tester, size: const Size(360, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(
      find.byKey(const ValueKey('shopping-search')),
      'milk',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Add shopping item'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets(
    'main screen has only compact add; pull refresh works on an empty list',
    (tester) async {
      await openScreen(tester, seed: false);
      expect(find.byTooltip('Reload shopping list'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Add Item'), findsNothing);
      expect(find.byTooltip('Add shopping item'), findsOneWidget);
      expect(find.text('Add your first item'), findsOneWidget);
      final reads = session.store.readCalls;
      session.store.seed('alice', 'milk', 'Milk');
      await pullRefresh(tester);
      expect(session.store.readCalls, reads + 1);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Your shopping list is empty'), findsNothing);
    },
  );

  testWidgets(
    'pull refresh keeps short list, tab, search and category collapse while loading',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('BOUGHT (1)'));
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'bread',
      );
      await tester.tap(find.text('Bakery (1)'));
      await tester.pumpAndSettle();
      session.store.documents['users/alice/shopping_items/bread']!['quantity'] =
          7;
      final reads = session.store.readCalls;
      final gate = Completer<void>();
      session.store.readGate = gate.future;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(session.store.readCalls, reads + 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(find.text('Bakery (1)'), findsOneWidget);
      expect(find.text('Bread'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shopping-search')))
            .controller!
            .text,
        'bread',
      );
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Bread'), findsNothing);
      await tester.tap(find.text('Bakery (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('7 pcs'), findsOneWidget);
    },
  );

  testWidgets(
    'pull refresh from no search matches reloads; refresh error can retry',
    (tester) async {
      await openScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'mango',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching items'), findsOneWidget);
      session.store.seed('alice', 'mango', 'Mango');
      await pullRefresh(tester);
      expect(find.text('Mango'), findsOneWidget);
      session.store.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await pullRefresh(tester);
      expect(
        find.text("Couldn't refresh. Showing your current list."),
        findsOneWidget,
      );
      expect(find.text('Mango'), findsOneWidget);
      session.store.readError = null;
      await pullRefresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Mango'), findsOneWidget);
    },
  );

  testWidgets(
    'quantity updates immediately, blocks double taps, and rolls back denied write',
    (tester) async {
      await openScreen(tester);
      final gate = Completer<void>();
      session.store.updateGate = gate.future;
      session.store.updateError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Update denied',
      );
      await tester.tap(find.byTooltip('Increase quantity of Milk'));
      await tester.pump();
      expect(
        visibleState(tester).firstWhere((item) => item.id == 'milk').quantity,
        3,
      );
      expect(
        session.store.documents['users/alice/shopping_items/milk']!['quantity'],
        2,
      );
      await tester.tap(find.byTooltip('Increase quantity of Milk'));
      expect(session.store.updateCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        visibleState(tester).firstWhere((item) => item.id == 'milk').quantity,
        2,
      );
      expect(find.textContaining("You don't have permission"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'checkbox immediately updates counts/filter and failed save restores both',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('BOUGHT (1)'));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      session.store.updateGate = gate.future;
      session.store.updateError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(find.text('BOUGHT (0)'), findsOneWidget);
      expect(find.text('TO BUY (3)'), findsOneWidget);
      expect(find.text('No bought items yet'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('BOUGHT (1)'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(
        session
            .store
            .documents['users/alice/shopping_items/bread']!['isPurchased'],
        isTrue,
      );
    },
  );

  testWidgets(
    'edit failure restores original document and displays error, not a duplicate',
    (tester) async {
      await openScreen(tester);
      session.store.updateError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await rowAction(tester, 'Milk', 'Edit item');
      await tester.enterText(find.byType(TextFormField).first, 'Fresh Milk');
      await tester.tap(find.text('Update Item'));
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Fresh Milk',
      );
      expect(
        session.store.documents['users/alice/shopping_items/milk']!['name'],
        'Milk',
      );
      expect(find.textContaining("You don't have permission"), findsOneWidget);
      expect(session.store.addCalls, 0);
      expect(session.store.documents.length, 3);
    },
  );

  testWidgets('account switch while editing cannot update the new account', (
    tester,
  ) async {
    await openScreen(tester);
    session.store.seed('bob', 'milk', 'Bob milk');
    await rowAction(tester, 'Milk', 'Edit item');
    await tester.enterText(find.byType(TextFormField).first, 'Alice edit');
    session.changeUser('bob');
    await tester.pumpAndSettle();
    expect(find.textContaining('Your account changed.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Bob milk'), findsOneWidget);
    expect(find.text('Alice edit'), findsNothing);
    expect(session.store.updateCalls, 0);
  });

  testWidgets(
    'pending failed write cannot restore previous account or show its error',
    (tester) async {
      await openScreen(tester);
      session.store.seed('bob', 'milk', 'Bob milk');
      final gate = Completer<void>();
      session.store.updateGate = gate.future;
      session.store.updateError = StateError('Alice write failed');
      await tester.tap(find.byTooltip('Increase quantity of Milk'));
      await tester.pump();
      session.changeUser('bob');
      await tester.pumpAndSettle();
      expect(find.text('Bob milk'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bob milk'), findsOneWidget);
      expect(find.textContaining('Alice write failed'), findsNothing);
      expect(visibleState(tester).single.quantity, 2);
    },
  );

  testWidgets(
    'empty filters give contextual messages and small empty add opens the form',
    (tester) async {
      await openScreen(tester, seed: false);
      await tester.tap(find.text('TO BUY (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No items to buy'), findsOneWidget);
      await tester.tap(find.text('BOUGHT (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No bought items yet'), findsOneWidget);
      await tester.tap(find.text('ALL (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your first item'));
      await tester.pumpAndSettle();
      expect(find.text('Add To Shopping List'), findsOneWidget);
    },
  );

  Future<void> submitDraft(
    WidgetTester tester,
    String name,
    String quantity,
  ) async {
    await tester.tap(find.byTooltip('Add shopping item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, name);
    await tester.enterText(find.byType(TextFormField).at(1), quantity);
    await tester.tap(find.widgetWithText(FilledButton, 'Add Item'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'To Buy duplicate dialog increases same document and guards double confirmation',
    (tester) async {
      session.store.seed('alice', 'milk', 'Milk');
      session.store.documents.values.single['quantity'] = 4;
      await openScreen(tester, seed: false);
      await submitDraft(tester, ' MILK ', '2');
      expect(find.text('Already on your list'), findsOneWidget);
      expect(find.textContaining('quantity 4'), findsOneWidget);
      final gate = Completer<void>();
      session.store.updateGate = gate.future;
      final choose = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Increase to 6'),
          )
          .onPressed!;
      choose();
      choose();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(session.store.updateCalls, 1);
      expect(session.store.addCalls, 0);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add Item'))
            .onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsNothing);
      expect(session.store.documents.length, 1);
      expect(session.store.documents.values.single['quantity'], 6);
      await pullRefresh(tester);
      expect(visibleState(tester).single.quantity, 6);
    },
  );

  testWidgets('Add Anyway deliberately creates a separate document', (
    tester,
  ) async {
    await openScreen(tester);
    await submitDraft(tester, 'milk', '2');
    expect(find.text('Already on your list'), findsOneWidget);
    await tester.tap(find.text('Add Anyway'));
    await tester.pumpAndSettle();
    expect(session.store.documents.length, 4);
    expect(session.store.addCalls, 1);
    expect(session.store.updateCalls, 0);
    expect(visibleState(tester).last.name, 'milk');
  });

  testWidgets(
    'Cancel keeps draft and performs no writes, including collapsed whitespace match',
    (tester) async {
      session.store.seed('alice', 'milk', 'Fresh Milk');
      await openScreen(tester, seed: false);
      final reads = session.store.readCalls;
      await submitDraft(tester, ' fresh   MILK ', '3');
      expect(find.text('Already on your list'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        ' fresh   MILK ',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '3',
      );
      expect(session.store.readCalls, reads);
      expect(session.store.addCalls, 0);
      expect(session.store.updateCalls, 0);
    },
  );

  for (final move in [true, false]) {
    testWidgets(
      'Bought duplicate ${move ? 'moves to To Buy' : 'allows another entry'}',
      (tester) async {
        session.store.seed('alice', 'milk', 'Milk', purchased: true);
        session.store.documents.values.single['quantity'] = 9;
        await openScreen(tester, seed: false);
        await submitDraft(tester, 'milk', '3');
        expect(find.text('Already bought'), findsOneWidget);
        expect(find.textContaining('quantity 3'), findsOneWidget);
        await tester.tap(find.text(move ? 'Move to To Buy' : 'Add Anyway'));
        await tester.pumpAndSettle();
        expect(session.store.documents.length, move ? 1 : 2);
        expect(
          session
              .store
              .documents['users/alice/shopping_items/milk']!['isPurchased'],
          !move,
        );
        expect(
          visibleState(
            tester,
          ).where((item) => !item.isPurchased).single.quantity,
          3,
        );
        expect(find.text('TO BUY (1)'), findsOneWidget);
        expect(find.text('BOUGHT (${move ? 0 : 1})'), findsOneWidget);
        await pullRefresh(tester);
        expect(
          visibleState(
            tester,
          ).where((item) => !item.isPurchased).single.quantity,
          3,
        );
      },
    );
  }

  testWidgets(
    'combined quantity limit disables increase; Cancel allows correction',
    (tester) async {
      session.store.seed('alice', 'milk', 'Milk');
      session.store.documents.values.single['quantity'] = 99;
      await openScreen(tester, seed: false);
      await submitDraft(tester, 'Milk', '2');
      expect(find.textContaining('Maximum quantity is 100.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Increase to 101'),
            )
            .onPressed,
        isNull,
      );
      expect(session.store.updateCalls, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '1');
      await tester.tap(find.widgetWithText(FilledButton, 'Add Item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Increase to 100'));
      await tester.pumpAndSettle();
      expect(session.store.documents.values.single['quantity'], 100);
    },
  );

  testWidgets(
    'edit duplicate Cancel retains input; Save Anyway keeps same ID and Bought',
    (tester) async {
      await openScreen(tester);
      await rowAction(tester, 'Bread', 'Edit item');
      await tester.enterText(find.byType(TextFormField).first, 'Milk');
      await tester.tap(find.text('Update Item'));
      await tester.pumpAndSettle();
      expect(find.text('This item name already exists'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.store.updateCalls, 0);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Milk',
      );
      await tester.tap(find.text('Update Item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Anyway'));
      await tester.pumpAndSettle();
      expect(session.store.documents['users/alice/shopping_items/bread'], {
        'name': 'Milk',
        'quantity': 2,
        'isPurchased': true,
        'unit': 'items',
        'category': 'Other',
      });
      expect(
        session
            .store
            .documents['users/alice/shopping_items/milk']!['isPurchased'],
        isFalse,
      );
      expect(session.store.documents.length, 3);
      expect(session.store.addCalls, 0);
    },
  );

  testWidgets(
    'search prefills Add and typing never triggers duplicate reads or writes',
    (tester) async {
      await openScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        '  milk  ',
      );
      await tester.tap(find.byTooltip('Add shopping item'));
      await tester.pumpAndSettle();
      final reads = session.store.readCalls;
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'milk',
      );
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Milk');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      expect(session.store.readCalls, reads);
      expect(session.store.addCalls, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Add Item'));
      await tester.pumpAndSettle();
      expect(find.text('Already on your list'), findsOneWidget);
    },
  );

  testWidgets(
    'filtered categories count only visible rows but tabs retain whole-list totals',
    (tester) async {
      session.store.seed('alice', 'cheese', 'Cheese', purchased: true);
      await openScreen(tester);
      expect(find.text('Dairy (2)'), findsOneWidget);
      await tester.tap(find.text('BOUGHT (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Dairy (1)'), findsOneWidget);
      expect(find.text('Grains (1)'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('shopping-search')),
        'CHEE',
      );
      await tester.pumpAndSettle();
      expect(find.text('Dairy (1)'), findsOneWidget);
      expect(find.text('Bakery (1)'), findsNothing);
      expect(find.text('ALL (4)'), findsOneWidget);
      expect(find.text('BOUGHT (2)'), findsOneWidget);
      expect(find.text('TO BUY (2)'), findsOneWidget);
      expect(session.store.updateCalls, 0);
    },
  );

  testWidgets(
    'failed duplicate increase retains draft and does not expose raw backend error',
    (tester) async {
      await openScreen(tester);
      await submitDraft(tester, 'MILK', '2');
      session.store.updateError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'PRIVATE DEBUG TEXT',
      );
      await tester.tap(find.text('Increase to 4'));
      await tester.pumpAndSettle();
      expect(find.textContaining("You don't have permission"), findsOneWidget);
      expect(find.textContaining('PRIVATE DEBUG TEXT'), findsNothing);
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'MILK',
      );
      expect(
        session.store.documents['users/alice/shopping_items/milk']!['quantity'],
        2,
      );
      expect(
        visibleState(tester).firstWhere((item) => item.id == 'milk').quantity,
        2,
      );
      expect(session.store.addCalls, 0);
    },
  );

  for (final edit in [false, true]) {
    testWidgets('rapid ${edit ? 'Update' : 'Add'} submission sends one write', (
      tester,
    ) async {
      await openScreen(tester, seed: edit);
      if (edit) {
        await rowAction(tester, 'Milk', 'Edit item');
      } else {
        await tester.tap(find.byTooltip('Add shopping item'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextFormField).first, 'Fresh item');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      final gate = Completer<void>();
      if (edit) {
        session.store.updateGate = gate.future;
      } else {
        session.store.addGate = gate.future;
      }
      final submit = tester
          .widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              edit ? 'Update Item' : 'Add Item',
            ),
          )
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(edit ? session.store.updateCalls : session.store.addCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                edit ? 'Update Item' : 'Add Item',
              ),
            )
            .onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsNothing);
      expect(edit ? session.store.updateCalls : session.store.addCalls, 1);
    });
  }

  testWidgets(
    'account change dismisses duplicate dialog and hides the old draft',
    (tester) async {
      await openScreen(tester);
      session.store.seed('bob', 'milk', 'Milk');
      await submitDraft(tester, 'MILK', '2');
      expect(find.byType(AlertDialog), findsOneWidget);
      session.changeUser('bob');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Your account changed.'), findsOneWidget);
      expect(session.store.addCalls, 0);
      expect(session.store.updateCalls, 0);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(visibleState(tester).length, 1);
    },
  );

  testWidgets(
    'duplicate dialog remains usable on a narrow phone with large text',
    (tester) async {
      session.store.seed(
        'alice',
        'milk',
        'A long custom milk name for the shopping list',
      );
      await openScreen(
        tester,
        seed: false,
        size: const Size(320, 640),
        textScale: 2,
      );
      await tester.tap(find.byTooltip('Add shopping item'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'A long custom milk name for the shopping list',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      final add = find.widgetWithText(FilledButton, 'Add Item');
      await tester.ensureVisible(add);
      expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Already on your list'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(session.store.addCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pantry match warns, Cancel preserves draft, and Add Anyway persists metadata',
    (tester) async {
      final pantryMilk = PantryItem(
        id: 'pantry-milk',
        firestoreId: 'pantry-milk',
        name: 'Milk',
        category: PantryCategory.dairy,
        location: PantryLocation.refrigerator,
        quantity: 2,
        unit: PantryUnit.liters,
      );
      await openScreen(tester, seed: false, pantryItems: [pantryMilk]);
      await tester.tap(find.byTooltip('Add shopping item'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Milk'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.pumpAndSettle();
      expect(find.text('2 L remaining in pantry'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<PantryUnit>>(
              find.byType(DropdownButtonFormField<PantryUnit>),
            )
            .initialValue,
        PantryUnit.liters,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'Dairy',
      );
      final add = find.widgetWithText(FilledButton, 'Add Item');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(session.store.addCalls, 0);
      expect(find.text('Already in your pantry'), findsOneWidget);
      expect(find.textContaining('Current quantity: 2 L'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.store.addCalls, 0);
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Anyway'));
      await tester.pumpAndSettle();
      final saved = session.store.documents.values.single;
      expect(saved['unit'], 'liters');
      expect(saved['category'], 'Dairy');
      expect(saved['quantity'], 2);
    },
  );

  testWidgets('low-stock suggestion adds once and carries pantry metadata', (
    tester,
  ) async {
    final pantryMilk = PantryItem(
      id: 'pantry-milk',
      firestoreId: 'pantry-milk',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.liters,
    );
    await openScreen(tester, seed: false, pantryItems: [pantryMilk]);
    expect(find.text('Low-stock suggestions (1)'), findsOneWidget);
    expect(find.text('Milk — only 1 L left'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Low-stock suggestions'), findsNothing);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 2),
    );
    expect(session.store.addCalls, 1);
    final saved = session.store.documents.values.single;
    expect(saved['source'], 'low_stock');
    expect(saved['sourcePantryItemId'], 'pantry-milk');
    expect(saved['unit'], 'liters');
    expect(saved['category'], 'Dairy');
  });

  testWidgets('dismiss only hides the suggestion and Undo restores it', (
    tester,
  ) async {
    final pantryMilk = lowStockItem(
      'pantry-milk',
      'Milk',
      unit: PantryUnit.bottles,
      category: PantryCategory.dairy,
    );
    final pantrySnapshot = pantryMilk.toMap();
    await openScreen(tester, seed: false, pantryItems: [pantryMilk]);

    await tester.tap(find.byTooltip('Dismiss Milk suggestion'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Low-stock suggestions'), findsNothing);
    expect(find.text('Milk suggestion dismissed.'), findsOneWidget);
    expect(session.store.addCalls, 0);
    expect(session.store.updateCalls, 0);
    expect(pantryMilk.toMap(), pantrySnapshot);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(find.text('Low-stock suggestions (1)'), findsOneWidget);
    expect(find.text('Milk — only 1 bottle left'), findsOneWidget);
  });

  testWidgets(
    'more than three suggestions are accessible and Add All adds all',
    (tester) async {
      final pantryItems = [
        lowStockItem('apples', 'Apples', quantity: 0),
        lowStockItem('eggs', 'Eggs'),
        lowStockItem(
          'milk',
          'Milk',
          unit: PantryUnit.liters,
          category: PantryCategory.dairy,
        ),
        lowStockItem('oranges', 'Oranges'),
      ];
      await openScreen(tester, seed: false, pantryItems: pantryItems);

      expect(find.byTooltip('Dismiss Apples suggestion'), findsOneWidget);
      expect(find.byTooltip('Dismiss Eggs suggestion'), findsOneWidget);
      expect(find.byTooltip('Dismiss Milk suggestion'), findsOneWidget);
      expect(find.byTooltip('Dismiss Oranges suggestion'), findsOneWidget);
      expect(find.text('Low-stock suggestions (4)'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Add All'));
      await tester.pumpAndSettle();

      expect(find.text('4 items added to your Shopping List.'), findsOneWidget);
      expect(visibleState(tester).map((item) => item.name), [
        'Apples',
        'Eggs',
        'Milk',
        'Oranges',
      ]);
      expect(session.store.addCalls, 4);
      expect(find.textContaining('Low-stock suggestions'), findsNothing);
      final milk = visibleState(
        tester,
      ).singleWhere((item) => item.name == 'Milk');
      expect(milk.quantity, 1);
      expect(milk.unit, PantryUnit.liters);
      expect(milk.category, 'Dairy');
    },
  );

  testWidgets(
    'Add All skips dismissed and existing items then hides an empty card',
    (tester) async {
      session.store.seed('alice', 'saved-milk', 'Milk');
      final pantryItems = [
        lowStockItem('milk', 'Milk'),
        lowStockItem('eggs', 'Eggs'),
        lowStockItem('oranges', 'Oranges'),
      ];
      await openScreen(tester, seed: false, pantryItems: pantryItems);

      expect(find.byTooltip('Dismiss Milk suggestion'), findsNothing);
      await tester.tap(find.byTooltip('Dismiss Eggs suggestion'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Add All'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Low-stock suggestions'), findsNothing);
      expect(visibleState(tester).map((item) => item.name), [
        'Milk',
        'Oranges',
      ]);
      expect(session.store.addCalls, 1);
      expect(
        visibleState(tester).where((item) => item.name == 'Milk'),
        hasLength(1),
      );
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'low-stock suggestion card renders in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        await openScreen(
          tester,
          seed: false,
          dark: dark,
          pantryItems: [lowStockItem('milk', 'Milk')],
        );
        expect(find.text('Low-stock suggestions (1)'), findsOneWidget);
        expect(find.text('Add All'), findsOneWidget);
        expect(find.byTooltip('Dismiss Milk suggestion'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('suggestions collapse to a count-only header and expand again', (
    tester,
  ) async {
    await openScreen(
      tester,
      seed: false,
      pantryItems: [lowStockItem('milk', 'Milk'), lowStockItem('eggs', 'Eggs')],
    );

    expect(find.text('Low-stock suggestions (2)'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Collapse low-stock suggestions')),
      findsOneWidget,
    );
    await tester.tap(find.text('Low-stock suggestions (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Add All'), findsNothing);
    expect(find.byTooltip('Dismiss Milk suggestion'), findsNothing);
    expect(find.text('Low-stock suggestions (2)'), findsOneWidget);

    expect(
      find.bySemanticsLabel(RegExp('Expand low-stock suggestions')),
      findsOneWidget,
    );
    await tester.tap(find.text('Low-stock suggestions (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Add All'), findsOneWidget);
    expect(find.byTooltip('Dismiss Milk suggestion'), findsOneWidget);
  });

  testWidgets(
    'suggestion expansion survives bottom-tab navigation and provider refreshes',
    (tester) async {
      session.store.seed('alice', 'bread', 'Bread');
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: AppRoutes.shopping,
        routes: [
          ShellRoute(
            builder: (context, state, child) => HomeShell(child: child),
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) =>
                    const Center(child: Text('Home destination')),
              ),
              GoRoute(
                path: AppRoutes.shopping,
                builder: (context, state) => const ShoppingListScreen(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shoppingListRepositoryProvider.overrideWithValue(
              session.repository,
            ),
            shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
            shoppingPantryItemsProvider.overrideWithValue(
              AsyncData([
                lowStockItem('milk', 'Milk'),
                lowStockItem('eggs', 'Eggs'),
              ]),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add All'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      await tester.tap(find.text('Low-stock suggestions (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bakery (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Add All'), findsNothing);
      expect(find.text('Low-stock suggestions (2)'), findsOneWidget);
      expect(find.text('Bakery (1)'), findsOneWidget);
      expect(find.text('Bread'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShoppingListScreen)),
      );
      container.invalidate(lowStockShoppingSuggestionsProvider);
      await tester.pump();
      expect(find.text('Add All'), findsNothing);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Low-stock suggestions (2)'), findsOneWidget);
      expect(find.text('Add All'), findsNothing);
      expect(find.text('Bread'), findsNothing);

      await tester.tap(find.text('Low-stock suggestions (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bakery (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Add All'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Add All'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);

      await tester.tap(find.text('Add All'));
      await tester.pumpAndSettle();
      expect(session.store.addCalls, 2);
      expect(find.textContaining('Low-stock suggestions'), findsNothing);
    },
  );

  testWidgets('suggestion and category expansion are isolated by account', (
    tester,
  ) async {
    session.store.seed('alice', 'bread', 'Bread');
    session.store.seed('bob', 'bread', 'Bread');
    await openScreen(
      tester,
      seed: false,
      pantryItems: [lowStockItem('milk', 'Milk')],
    );
    await tester.tap(find.text('Low-stock suggestions (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bakery (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Add All'), findsNothing);
    expect(find.text('Bread'), findsNothing);

    session.changeUser('bob');
    await tester.pumpAndSettle();
    expect(find.text('Add All'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);

    session.changeUser('alice');
    await tester.pumpAndSettle();
    expect(find.text('Low-stock suggestions (1)'), findsOneWidget);
    expect(find.text('Add All'), findsNothing);
    expect(find.text('Bread'), findsNothing);
  });

  testWidgets(
    'master setting hides suggestions and threshold updates show them',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'low_stock_suggestions.alice.enabled': false,
      });
      final preferences = await SharedPreferences.getInstance();
      final milk = lowStockItem(
        'milk',
        'Milk',
        quantity: 2,
        category: PantryCategory.dairy,
      );
      await openScreen(
        tester,
        seed: false,
        pantryItems: [milk],
        preferences: preferences,
      );
      expect(find.textContaining('Low-stock suggestions'), findsNothing);

      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(ShoppingListScreen)),
      );
      final notifier = providerContainer.read(
        lowStockSuggestionSettingsProvider.notifier,
      );
      notifier.setEnabled(true);
      await tester.pump();
      expect(find.textContaining('Low-stock suggestions'), findsNothing);
      notifier.setThreshold(PantryCategory.dairy, 2);
      await tester.pump();
      expect(find.text('Low-stock suggestions (1)'), findsOneWidget);
    },
  );

  testWidgets(
    'Dismiss All confirms, hides all, and Undo restores only its set',
    (tester) async {
      await openScreen(
        tester,
        seed: false,
        pantryItems: [
          lowStockItem('milk', 'Milk'),
          lowStockItem('eggs', 'Eggs'),
          lowStockItem('oranges', 'Oranges'),
        ],
      );
      await tester.tap(find.byTooltip('Dismiss Milk suggestion'));
      await tester.pump();
      await tester.tap(find.text('Low-stock suggestions (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low-stock suggestions (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss All'));
      await tester.pumpAndSettle();
      expect(find.text('Dismiss all suggestions?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Low-stock suggestions (2)'), findsOneWidget);

      await tester.tap(find.text('Dismiss All'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Dismiss All'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Low-stock suggestions'), findsNothing);
      expect(find.text('2 low-stock suggestions dismissed.'), findsOneWidget);
      expect(session.store.addCalls, 0);
      expect(session.store.updateCalls, 0);
      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      expect(find.text('Low-stock suggestions (2)'), findsOneWidget);
      expect(find.byTooltip('Dismiss Milk suggestion'), findsNothing);
    },
  );

  testWidgets('transient SnackBars replace each other and auto-dismiss', (
    tester,
  ) async {
    await openScreen(
      tester,
      seed: false,
      pantryItems: [lowStockItem('milk', 'Milk'), lowStockItem('eggs', 'Eggs')],
    );
    await tester.tap(find.byTooltip('Dismiss Eggs suggestion'));
    await tester.pump();
    expect(find.text('Eggs suggestion dismissed.'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 3),
    );

    await tester.tap(find.byTooltip('Dismiss Milk suggestion'));
    await tester.pump();
    expect(find.text('Eggs suggestion dismissed.'), findsNothing);
    expect(find.text('Milk suggestion dismissed.'), findsOneWidget);
    for (var second = 0; second < 10; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Milk suggestion dismissed.'), findsNothing);
  });

  testWidgets('Add All confirms before adding more than five suggestions', (
    tester,
  ) async {
    final pantryItems = List.generate(
      6,
      (index) => lowStockItem('item-$index', 'Item $index'),
    );
    await openScreen(tester, seed: false, pantryItems: pantryItems);
    await tester.tap(find.text('Add All'));
    await tester.pumpAndSettle();
    expect(
      find.text('Add 6 suggested items to your Shopping List?'),
      findsOneWidget,
    );
    expect(session.store.addCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Add All'));
    await tester.pumpAndSettle();
    expect(session.store.addCalls, 6);
    expect(find.text('6 items added to your Shopping List.'), findsOneWidget);
  });

  testWidgets('Bought item opens a prefilled Pantry add flow', (tester) async {
    session.store.seed('alice', 'milk', 'Milk');
    await openScreen(tester, seed: false);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.textContaining('Add it to Pantry?'), findsOneWidget);
    await tester.tap(find.text('Add to Pantry'));
    await tester.pumpAndSettle();
    expect(find.byType(PantryItemFormScreen), findsOneWidget);
    expect(find.text('Add Item'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'Milk',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '2',
    );
    expect(find.text('Dairy'), findsOneWidget);
  });

  testWidgets('Bought pantry match opens existing quantity editor', (
    tester,
  ) async {
    session.store.seed('alice', 'milk', 'Milk');
    final pantryMilk = PantryItem(
      id: 'pantry-milk',
      firestoreId: 'pantry-milk',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.liters,
    );
    await openScreen(tester, seed: false, pantryItems: [pantryMilk]);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.textContaining('Update its Pantry quantity?'), findsOneWidget);
    await tester.tap(find.text('Update Pantry'));
    await tester.pumpAndSettle();
    expect(find.byType(PantryItemFormScreen), findsOneWidget);
    expect(find.text('Edit Item'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '1',
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Add form at narrow width/text scale $scale keeps one quantity value and quick picks',
      (tester) async {
        await openScreen(
          tester,
          seed: false,
          size: const Size(320, 640),
          textScale: scale,
          dark: scale == 2,
        );
        await tester.tap(find.byTooltip('Add shopping item'));
        await tester.pumpAndSettle();
        final chip = find.widgetWithText(ActionChip, 'Milk');
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Milk',
        );
        final quantity = find.byType(TextFormField).at(1);
        await tester.ensureVisible(quantity);
        await tester.enterText(quantity, '99');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Increase item quantity'));
        await tester.tap(find.byTooltip('Increase item quantity'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(quantity).controller!.text, '100');
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Increase item quantity',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(quantity, '1');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Decrease item quantity',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        final add = find.widgetWithText(FilledButton, 'Add Item');
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(session.store.addCalls, 1);
        expect(session.store.documents.values.single['quantity'], 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'narrow mobile and large text ($scale) have no layout overflow',
      (tester) async {
        session.store.seed(
          'alice',
          'custom',
          'A long custom shopping item name that stays readable',
        );
        await openScreen(
          tester,
          seed: false,
          size: const Size(320, 640),
          textScale: scale,
          dark: scale == 2,
        );
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Add shopping item'), findsOneWidget);
        final name = find.text(
          'A long custom shopping item name that stays readable',
        );
        await tester.ensureVisible(name);
        await tester.longPressAt(
          tester.getTopLeft(name) + const Offset(12, 12),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Cancel selection'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
