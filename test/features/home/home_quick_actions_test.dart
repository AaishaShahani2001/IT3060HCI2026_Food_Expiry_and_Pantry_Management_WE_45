import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/record_waste_screen.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/screens/pantry_item_form_screen.dart';
import 'package:go_router/go_router.dart';

import '../food_waste_tracking/support/waste_test_session.dart';

class _ScriptedPantryItemsNotifier extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => Stream.value(const []);
}

class _EmptyWaste extends FoodWasteNotifier {
  @override
  Future<List<FoodWasteRecord>> build() async => const [];
}

void main() {
  late GoRouter router;
  late WasteTestSession session;

  setUp(() {
    session = WasteTestSession();
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: HomeQuickActions()),
          ),
        ),
        GoRoute(
          path: AppRoutes.shopping,
          builder: (_, _) => const Scaffold(body: Text('Shopping destination')),
        ),
      ],
    );
  });

  Future<void> pumpActions(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(360, 800),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(router.dispose);
    addTearDown(session.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
          foodWasteRepositoryProvider.overrideWithValue(session.repository),
          wasteAuthUidProvider.overrideWith((ref) => session.auth()),
          foodWasteProvider.overrideWith(_EmptyWaste.new),
        ],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows one shortcut row and opens existing destinations', (
    tester,
  ) async {
    await pumpActions(tester);

    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Shortcuts'), findsOneWidget);
    expect(find.text('+ Add'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-quick-add-item')));
    await tester.pumpAndSettle();
    expect(find.byType(PantryItemFormScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(PantryItemFormScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-quick-shopping')));
    await tester.pumpAndSettle();
    expect(find.text('Shopping destination'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-quick-record-waste')));
    await tester.pumpAndSettle();
    expect(find.byType(RecordWasteScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(RecordWasteScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-quick-scan-barcode')));
    await tester.pump();
    expect(find.text('Barcode scanning is not available yet.'), findsOneWidget);
  });

  testWidgets('fits a narrow phone in dark mode at large text', (tester) async {
    await pumpActions(
      tester,
      theme: AppTheme.dark,
      size: const Size(320, 700),
      scale: 2,
    );
    expect(find.byKey(const ValueKey('home-quick-actions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
