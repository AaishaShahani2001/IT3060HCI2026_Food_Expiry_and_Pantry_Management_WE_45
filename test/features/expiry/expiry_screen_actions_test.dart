import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/screens/expiry_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('expiry actions stay responsive and open their existing routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
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
          expirySummaryProvider.overrideWithValue((
            total: 0,
            expired: 0,
            expiringSoon: 0,
            fresh: 0,
            unknown: 0,
          )),
          smartAlertItemsProvider.overrideWithValue(const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final wasteButton = find.byKey(const ValueKey('track-waste-button'));
    final expiryButton = find.byKey(const ValueKey('track-item-expiry-button'));
    expect(wasteButton, findsOneWidget);
    expect(expiryButton, findsOneWidget);
    expect(
      tester.getCenter(wasteButton).dx,
      lessThan(tester.getCenter(expiryButton).dx),
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
}
