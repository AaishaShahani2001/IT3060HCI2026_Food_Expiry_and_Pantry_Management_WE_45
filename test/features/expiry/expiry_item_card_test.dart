import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/screens/expiry_screen.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:go_router/go_router.dart';

List<PantryItem> _pantryItems = const [];

class _ScriptedPantryItemsNotifier extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => Stream.value(_pantryItems);
}

PantryItem _item({
  required String id,
  required String name,
  required PantryCategory category,
  required PantryLocation location,
  required double quantity,
  required PantryUnit unit,
  DateTime? expiryDate,
  String? photoUrl,
}) {
  return PantryItem(
    id: id,
    name: name,
    category: category,
    location: location,
    quantity: quantity,
    unit: unit,
    expiryDate: expiryDate,
    photoUrl: photoUrl,
  );
}

void main() {
  setUp(() {
    _pantryItems = const [];
  });

  testWidgets('compact cards show details and keep actions behind the menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    _pantryItems = [
      _item(
        id: 'milk',
        name: 'Milk',
        category: PantryCategory.dairy,
        location: PantryLocation.refrigerator,
        quantity: 2,
        unit: PantryUnit.bottles,
        expiryDate: day,
      ),
    ];

    final router = GoRouter(
      initialLocation: AppRoutes.expiry,
      routes: [
        GoRoute(
          path: AppRoutes.expiry,
          builder: (context, state) => const ExpiryScreen(),
        ),
        GoRoute(
          path: AppRoutes.editExpiryTracking,
          builder: (context, state) =>
              const Scaffold(body: Text('Update Expiry destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('2 bottles • Refrigerator'), findsOneWidget);
    expect(find.textContaining('Expires today'), findsOneWidget);
    expect(find.text('URGENT'), findsOneWidget);
    expect(find.byIcon(PantryCategory.dairy.icon), findsOneWidget);
    expect(find.text('Update'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Milk, 2 bottles, refrigerator, expires today, urgent',
      ),
      findsOneWidget,
    );

    final milk = tester.getRect(find.byKey(const ValueKey('milk')));
    final screen = tester.view.physicalSize.width;
    expect(milk.width, lessThan(screen - 16));

    await tester.tap(find.byTooltip('Item actions'));
    await tester.pumpAndSettle();
    expect(find.text('Update Expiry'), findsOneWidget);
    expect(find.text('Change the tracked expiry date'), findsOneWidget);
    expect(find.text('Stop Tracking'), findsOneWidget);
    expect(find.text('Remove expiry tracking only'), findsOneWidget);
    expect(find.byIcon(Icons.edit_calendar_outlined), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

    await tester.tap(find.text('Stop Tracking'));
    await tester.pumpAndSettle();
    expect(find.text('Stop tracking Milk?'), findsOneWidget);
    expect(
      find.text(
        'Milk will remain in your pantry, but its expiry date will no longer be tracked.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Stop tracking Milk?'), findsNothing);

    await tester.tap(find.byTooltip('Item actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Expiry'));
    await tester.pumpAndSettle();
    expect(find.text('Update Expiry destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide expiry lists place two cards in one row', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final yesterday = DateTime.now().subtract(const Duration(days: 2));
    _pantryItems = [
      _item(
        id: 'bread',
        name: 'Bread',
        category: PantryCategory.grains,
        location: PantryLocation.pantry,
        quantity: 1,
        unit: PantryUnit.items,
        expiryDate: yesterday,
      ),
      _item(
        id: 'cheese',
        name: 'Cheese',
        category: PantryCategory.dairy,
        location: PantryLocation.refrigerator,
        quantity: 1,
        unit: PantryUnit.packs,
        expiryDate: yesterday,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ExpiryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final bread = tester.getRect(find.byKey(const ValueKey('bread')));
    final cheese = tester.getRect(find.byKey(const ValueKey('cheese')));
    expect((bread.top - cheese.top).abs(), lessThan(2));
    expect(bread.left, lessThan(cheese.left));
    expect(bread.width, lessThan(500));
    expect(bread.left, greaterThan(100));
    expect(find.text('CRITICAL'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed item photo shows the category icon', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _pantryItems = [
      _item(
        id: 'milk',
        name: 'Milk',
        category: PantryCategory.dairy,
        location: PantryLocation.refrigerator,
        quantity: 1,
        unit: PantryUnit.bottles,
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        photoUrl:
            'https://res.cloudinary.com/test-cloud/image/upload/v1/missing.jpg',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ExpiryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(PantryCategory.dairy.icon), findsOneWidget);
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
