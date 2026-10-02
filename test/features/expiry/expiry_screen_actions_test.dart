import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_provider.dart';
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
  DateTime? expiryDate,
}) {
  return PantryItem(
    id: id,
    name: name,
    category: PantryCategory.other,
    location: PantryLocation.pantry,
    quantity: 1,
    unit: PantryUnit.items,
    expiryDate: expiryDate,
  );
}

void main() {
  setUp(() {
    _pantryItems = const [];
  });

  testWidgets('expiry actions stay responsive and open their existing routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoutes.expiry,
      routes: [
        GoRoute(
          path: AppRoutes.expiry,
          builder: (context, state) => const ExpiryScreen(),
        ),
        GoRoute(
          path: AppRoutes.wasteTracker,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Waste Tracker destination')),
          ),
        ),
        GoRoute(
          path: AppRoutes.addExpiryTracking,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Track Item Expiry destination')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
          expirySummaryProvider.overrideWithValue((
            total: 0,
            expired: 0,
            expiringSoon: 0,
            fresh: 0,
            unknown: 0,
          )),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final wasteButton = find.byKey(const ValueKey('track-waste-button'));
    final expiryButton = find.byKey(const ValueKey('track-item-expiry-button'));
    expect(wasteButton, findsOneWidget);
    expect(expiryButton, findsOneWidget);
    expect(
      tester.getCenter(expiryButton).dx,
      lessThan(tester.getCenter(wasteButton).dx),
    );
    expect(
      tester.getTopLeft(find.text('Fresh 0')).dy,
      lessThan(tester.getTopLeft(expiryButton).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(wasteButton);
    await tester.pumpAndSettle();
    expect(find.text('Waste Tracker destination'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(expiryButton);
    await tester.pumpAndSettle();
    expect(find.text('Track Item Expiry destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiry actions do not overflow on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: ExpiryTrackingActions(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track Waste'), findsOneWidget);
    expect(find.text('Track Item Expiry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status labels filter tracked items and keep summary counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    _pantryItems = [
      _item(
        id: 'fresh',
        name: 'Yogurt',
        expiryDate: now.add(const Duration(days: 14)),
      ),
      _item(
        id: 'soon',
        name: 'Milk',
        expiryDate: now.add(const Duration(days: 1)),
      ),
      _item(
        id: 'expired',
        name: 'Bread',
        expiryDate: now.subtract(const Duration(days: 3)),
      ),
      _item(id: 'unknown', name: 'Rice'),
    ];

    final router = GoRouter(
      initialLocation: AppRoutes.expiry,
      routes: [
        GoRoute(
          path: AppRoutes.expiry,
          builder: (context, state) => const ExpiryScreen(),
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

    expect(find.text('All 3'), findsNothing);
    expect(find.text('Fresh 1'), findsOneWidget);
    expect(find.text('Expiring Soon 1'), findsOneWidget);
    expect(find.text('Expired 1'), findsOneWidget);
    final freshLabel = tester.getTopLeft(find.text('Fresh 1'));
    final soonLabel = tester.getTopLeft(find.text('Expiring Soon 1'));
    final expiredLabel = tester.getTopLeft(find.text('Expired 1'));
    expect((freshLabel.dy - soonLabel.dy).abs(), lessThan(2));
    expect((freshLabel.dy - expiredLabel.dy).abs(), lessThan(2));
    expect(freshLabel.dx, lessThan(soonLabel.dx));
    expect(soonLabel.dx, lessThan(expiredLabel.dx));
    expect(find.text('Yogurt'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    expect(find.text('USE FIRST'), findsWidgets);
    expect(find.text('HIGH PRIORITY'), findsOneWidget);
    expect(find.text('EXPIRED ITEMS'), findsOneWidget);
    expect(find.text('Action Needed'), findsOneWidget);
    expect(find.text('EXPIRING SOON'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Milk')).dy,
      lessThan(tester.getTopLeft(find.text('Bread')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bread')).dy,
      lessThan(tester.getTopLeft(find.text('Yogurt')).dy),
    );

    await tester.tap(find.text('Fresh 1'));
    await tester.pumpAndSettle();
    expect(find.text('Yogurt'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsNothing);

    await tester.tap(find.text('Expiring Soon 1'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Yogurt'), findsNothing);

    await tester.tap(find.text('Expired 1'));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);

    await tester.tap(find.text('Expired 1'));
    await tester.pumpAndSettle();
    expect(find.text('Yogurt'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty status filter explains that status and can show all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _pantryItems = [
      _item(
        id: 'expired',
        name: 'Bread',
        expiryDate: DateTime.now().subtract(const Duration(days: 2)),
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

    await tester.tap(find.text('Fresh 0'));
    await tester.pumpAndSettle();

    expect(find.text('No fresh items found'), findsOneWidget);
    expect(find.text('No expiry items'), findsNothing);
    expect(find.text('Bread'), findsNothing);

    await tester.tap(find.text('Show All'));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiry screen background follows light and dark themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpTheme(ThemeData theme) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
          ],
          child: MaterialApp(theme: theme, home: const ExpiryScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpTheme(AppTheme.light);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.cream,
    );

    await pumpTheme(AppTheme.dark);
    final darkScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(darkScaffold.backgroundColor, AppTheme.dark.colorScheme.surface);
    expect(darkScaffold.backgroundColor, isNot(AppColors.cream));
    expect(tester.takeException(), isNull);
  });
}
