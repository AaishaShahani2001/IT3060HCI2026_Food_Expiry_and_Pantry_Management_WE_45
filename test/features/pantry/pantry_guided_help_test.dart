import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/pantry_scope.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/active_pantry_scope_provider.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_guided_help_provider.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/screens/pantry_screen.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:food_expiry_and_pantry_management/core/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SeedPantry extends PantryItemsNotifier {
  _SeedPantry(this.items);

  final List<PantryItem> items;

  @override
  Stream<List<PantryItem>> build() => Stream.value(items);
}

class _ControlledPantry extends PantryItemsNotifier {
  _ControlledPantry(this.controller);

  final StreamController<List<PantryItem>> controller;

  @override
  Stream<List<PantryItem>> build() => controller.stream;
}

class _ControlledPantryHarness {
  const _ControlledPantryHarness({
    required this.container,
    required this.controller,
  });

  final ProviderContainer container;
  final StreamController<List<PantryItem>> controller;
}

PantryItem _milk() => PantryItem(
  id: 'milk',
  firestoreId: 'milk',
  name: 'Milk',
  category: PantryCategory.dairy,
  location: PantryLocation.refrigerator,
  quantity: 1,
  unit: PantryUnit.bottles,
  expiryDate: DateTime.now().add(const Duration(days: 2)),
);

Future<ProviderContainer> _pumpPantry(
  WidgetTester tester, {
  Size size = const Size(430, 900),
  double textScale = 1,
  PantryScope scope = const PantryScope.personal(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final item = _milk();
  final container = ProviderContainer(
    overrides: [
      pantryItemsProvider.overrideWith(() => _SeedPantry([item])),
      activePantryScopeProvider.overrideWith((ref) => Stream.value(scope)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const PantryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<_ControlledPantryHarness> _pumpControlledPantry(
  WidgetTester tester, {
  required List<PantryItem> initialItems,
  String uid = 'alice',
  PantryScope scope = const PantryScope.personal(),
  Size size = const Size(430, 900),
  Map<String, Object> storedValues = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(storedValues);
  final preferences = await SharedPreferences.getInstance();
  final stream = StreamController<List<PantryItem>>.broadcast();
  addTearDown(stream.close);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      pantryHelpUidProvider.overrideWithValue(uid),
      pantryItemsProvider.overrideWith(() => _ControlledPantry(stream)),
      activePantryScopeProvider.overrideWith((ref) => Stream.value(scope)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PantryScreen()),
    ),
  );
  await tester.pump();
  stream.add(initialItems);
  await tester.pumpAndSettle();
  return _ControlledPantryHarness(container: container, controller: stream);
}

Future<void> _repumpControlledPantry(
  WidgetTester tester,
  _ControlledPantryHarness harness,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const MaterialApp(home: PantryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void _recordLoadedEmptyPantry(_ControlledPantryHarness harness) {
  harness.container
      .read(pantryFirstItemHelpProvider.notifier)
      .recordEmptyPantrySeen();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pantry info opens help and Next and Skip do not change data', (
    tester,
  ) async {
    final container = await _pumpPantry(tester);
    final before = container.read(pantryItemsProvider).requireValue.single;

    expect(find.byTooltip('Pantry help'), findsOneWidget);
    await tester.tap(find.byTooltip('Pantry help'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shopping-help-card')), findsOneWidget);
    expect(find.text('Personal or Shared Pantry'), findsOneWidget);
    expect(find.text('1 of 7'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Filter by Location'), findsOneWidget);
    expect(find.text('2 of 7'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shopping-help-card')), findsNothing);
    expect(
      container.read(pantryItemsProvider).requireValue.single,
      same(before),
    );
  });

  testWidgets('Pantry help targets all seven controls and Done closes it', (
    tester,
  ) async {
    final container = await _pumpPantry(
      tester,
      scope: const PantryScope.shared('Home'),
    );
    final before = container.read(pantryItemsProvider).requireValue.single;

    expect(find.text('Home • Shared'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Refrigerator'), findsOneWidget);
    expect(find.text('View All (1)'), findsOneWidget);
    expect(find.byType(PantryItemCard), findsOneWidget);
    expect(find.byTooltip('Decrease quantity'), findsOneWidget);
    expect(find.byTooltip('Increase quantity'), findsOneWidget);
    expect(find.byTooltip('Actions for Milk'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add Item'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Pantry help'));
    await tester.pumpAndSettle();

    const titles = [
      'Personal or Shared Pantry',
      'Filter by Location',
      'View All Pantry Items',
      'Pantry Item Details',
      'Update Quantity',
      'Item Actions',
      'Add Pantry Items',
    ];
    for (var index = 0; index < titles.length; index++) {
      expect(find.text(titles[index]), findsOneWidget);
      expect(find.text('${index + 1} of ${titles.length}'), findsOneWidget);
      if (titles[index] == 'Pantry Item Details') {
        expect(
          find.textContaining(
            'Fresh, Expiring soon, Expired, or Expiry date unknown',
          ),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          index == titles.length - 1 ? 'Done' : 'Next',
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('shopping-help-card')), findsNothing);
    expect(
      container.read(pantryItemsProvider).requireValue.single,
      same(before),
    );
  });

  testWidgets('Pantry help has no overflow on a compact phone screen', (
    tester,
  ) async {
    await _pumpPantry(tester, size: const Size(375, 667));

    await tester.tap(find.byTooltip('Pantry help'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 7; index++) {
      expect(find.text('${index + 1} of 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(FilledButton, index == 6 ? 'Done' : 'Next'),
      );
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('shopping-help-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Pantry waits for a real first-item transition', (
    tester,
  ) async {
    await _pumpControlledPantry(tester, initialItems: const []);

    expect(
      find.byKey(const ValueKey('pantry-first-item-help-prompt')),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Pantry help'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Personal or Shared Pantry'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'first item prompts after Add Item navigation and screen recreation',
    (tester) async {
      final harness = await _pumpControlledPantry(
        tester,
        initialItems: const [],
      );

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Item'));
      await tester.pumpAndSettle();
      expect(
        harness.container.read(pantryFirstItemHelpProvider).sawEmptyPantry,
        isTrue,
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      harness.controller.add([_milk()]);
      await tester.pump();
      await _repumpControlledPantry(tester, harness);

      await tester.pumpAndSettle();
      expect(find.text('Your first pantry item is ready!'), findsOneWidget);
      expect(
        find.text('Want a quick tour of the item controls?'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Continue guide'));
      await tester.pumpAndSettle();
      const itemTitles = [
        'Pantry Item Details',
        'Update Quantity',
        'Item Actions',
      ];
      for (var index = 0; index < itemTitles.length; index++) {
        expect(find.text(itemTitles[index]), findsOneWidget);
        expect(find.text('${index + 1} of 3'), findsOneWidget);
        expect(find.text('Personal or Shared Pantry'), findsNothing);
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            index == itemTitles.length - 1 ? 'Done' : 'Next',
          ),
        );
        await tester.pumpAndSettle();
      }

      harness.controller.add([_milk(), _milk().copyWith(id: 'eggs')]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pantry-first-item-help-prompt')),
        findsNothing,
      );

      harness.container.invalidate(pantryItemsProvider);
      await tester.pump();
      harness.controller.add([_milk()]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pantry-first-item-help-prompt')),
        findsNothing,
      );
    },
  );

  testWidgets('Not now persists per user and shared Pantry scope', (
    tester,
  ) async {
    final harness = await _pumpControlledPantry(
      tester,
      initialItems: const [],
      scope: const PantryScope.shared('Home', 'home-id'),
    );
    _recordLoadedEmptyPantry(harness);
    harness.controller.add([_milk()]);
    await tester.pumpAndSettle();
    expect(
      harness.container.read(pantryFirstItemHelpProvider).sawEmptyPantry,
      isTrue,
    );
    expect(
      harness.container.read(pantryFirstItemHelpProvider).prompted,
      isTrue,
    );
    expect(find.text('Home • Shared'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Not now'));
    await tester.pumpAndSettle();
    harness.controller.add(const []);
    await tester.pumpAndSettle();
    harness.controller.add([_milk()]);
    await tester.pumpAndSettle();
    expect(find.text('Your first pantry item is ready!'), findsNothing);

    await tester.tap(find.byTooltip('Pantry help'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 7'), findsOneWidget);
    expect(find.text('Personal or Shared Pantry'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(
      harness.container
          .read(sharedPreferencesProvider)
          ?.getBool(
            pantryFirstItemHelpPromptedStorageKey('alice', 'shared.home-id'),
          ),
      isTrue,
    );
  });

  testWidgets('loading or failed first add does not show the prompt', (
    tester,
  ) async {
    final harness = await _pumpControlledPantry(tester, initialItems: const []);
    _recordLoadedEmptyPantry(harness);
    harness.controller.addError(Exception('save failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your first pantry item is ready!'), findsNothing);
    expect(
      harness.container.read(pantryFirstItemHelpProvider).prompted,
      isFalse,
    );
  });

  testWidgets('first-item prompt persistence is isolated by account', (
    tester,
  ) async {
    final alice = await _pumpControlledPantry(tester, initialItems: const []);
    _recordLoadedEmptyPantry(alice);
    alice.controller.add([_milk()]);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Not now'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final bob = await _pumpControlledPantry(
      tester,
      uid: 'bob',
      initialItems: const [],
      storedValues: {
        pantryFirstItemHelpSawEmptyStorageKey('alice', 'personal'): true,
        pantryFirstItemHelpPromptedStorageKey('alice', 'personal'): true,
      },
    );
    _recordLoadedEmptyPantry(bob);
    bob.controller.add([_milk()]);
    await tester.pumpAndSettle();

    expect(find.text('Your first pantry item is ready!'), findsOneWidget);
    expect(bob.container.read(pantryFirstItemHelpProvider).prompted, isTrue);
  });

  testWidgets('Personal and Shared Pantry prompt state is isolated', (
    tester,
  ) async {
    final shared = await _pumpControlledPantry(
      tester,
      initialItems: const [],
      scope: const PantryScope.shared('Home', 'home-id'),
    );
    _recordLoadedEmptyPantry(shared);
    shared.controller.add([_milk()]);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Not now'));
    await tester.pumpAndSettle();

    final preferences = shared.container.read(sharedPreferencesProvider)!;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final personal = await _pumpControlledPantry(
      tester,
      initialItems: const [],
      storedValues: {
        pantryFirstItemHelpSawEmptyStorageKey(
          'alice',
          'shared.home-id',
        ): preferences.getBool(
          pantryFirstItemHelpSawEmptyStorageKey('alice', 'shared.home-id'),
        )!,
        pantryFirstItemHelpPromptedStorageKey(
          'alice',
          'shared.home-id',
        ): preferences.getBool(
          pantryFirstItemHelpPromptedStorageKey('alice', 'shared.home-id'),
        )!,
      },
    );
    _recordLoadedEmptyPantry(personal);
    personal.controller.add([_milk()]);
    await tester.pumpAndSettle();

    expect(find.text('Your first pantry item is ready!'), findsOneWidget);
  });

  testWidgets('an already populated Pantry never auto-opens the dialog', (
    tester,
  ) async {
    final harness = await _pumpControlledPantry(
      tester,
      initialItems: [_milk()],
    );

    expect(find.text('Your first pantry item is ready!'), findsNothing);
    expect(
      harness.container.read(pantryFirstItemHelpProvider).sawEmptyPantry,
      isFalse,
    );
  });

  testWidgets('first-item prompt and continuation fit a compact phone', (
    tester,
  ) async {
    final harness = await _pumpControlledPantry(
      tester,
      initialItems: const [],
      size: const Size(375, 667),
    );
    _recordLoadedEmptyPantry(harness);
    harness.controller.add([_milk()]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue guide'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      expect(find.text('${index + 1} of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(FilledButton, index == 2 ? 'Done' : 'Next'),
      );
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
