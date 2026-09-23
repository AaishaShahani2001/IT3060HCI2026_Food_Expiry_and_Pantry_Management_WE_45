import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_pantry_summary_card.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:go_router/go_router.dart';

import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';

class _TestPantryItemsNotifier extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => Stream.value(const []);
}

void main() {
  late GoRouter router;
  bool navigatedToPantry = false;

  setUp(() {
    navigatedToPantry = false;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(
              child: HomePantrySummaryCard(),
            ),
          ),
        ),
        GoRoute(
          path: '/pantry',
          builder: (_, _) {
            navigatedToPantry = true;
            return const Scaffold(body: Text('Pantry Screen'));
          },
        ),
      ],
    );
  });

  Future<void> pumpPantryCard(
    WidgetTester tester, {
    int totalItems = 24,
    int expiringSoonItems = 5,
    Size size = const Size(430, 900),
    double textScale = 1.0,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_TestPantryItemsNotifier.new),
          pantrySummaryProvider.overrideWithValue(
            (total: totalItems, lowStock: 0),
          ),
          expirySummaryProvider.overrideWithValue(
            (
              total: totalItems,
              expired: 0,
              expiringSoon: expiringSoonItems,
              fresh: totalItems - expiringSoonItems,
              unknown: 0,
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('HomePantrySummaryCard renders Your Pantry header and 2 stat cards', (
    tester,
  ) async {
    await pumpPantryCard(tester, totalItems: 24, expiringSoonItems: 5);

    expect(find.byType(HomePantrySummaryCard), findsOneWidget);
    expect(find.text('Your Pantry'), findsOneWidget);
    expect(find.text('Keep track of your food items'), findsOneWidget);

    expect(find.text('24'), findsOneWidget);
    expect(find.text('Total Items'), findsOneWidget);

    expect(find.text('5'), findsOneWidget);
    expect(find.text('Expiring Soon'), findsOneWidget);
  });

  testWidgets('HomePantrySummaryCard correctly shows 0 when pantry is empty', (
    tester,
  ) async {
    await pumpPantryCard(tester, totalItems: 0, expiringSoonItems: 0);

    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Total Items'), findsOneWidget);
    expect(find.text('Expiring Soon'), findsOneWidget);
  });

  testWidgets('Tapping HomePantrySummaryCard navigates to pantry management screen', (
    tester,
  ) async {
    await pumpPantryCard(tester);

    await tester.tap(find.byType(HomePantrySummaryCard));
    await tester.pumpAndSettle();

    expect(navigatedToPantry, isTrue);
    expect(find.text('Pantry Screen'), findsOneWidget);
  });

  testWidgets('Renders properly in dark mode without crashing', (tester) async {
    await pumpPantryCard(
      tester,
      theme: AppTheme.dark,
      totalItems: 12,
      expiringSoonItems: 3,
    );

    expect(find.text('Your Pantry'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No overflow on narrow mobile screen with enlarged text scale', (
    tester,
  ) async {
    await pumpPantryCard(
      tester,
      totalItems: 9999,
      expiringSoonItems: 888,
      size: const Size(320, 700),
      textScale: 1.5,
    );

    expect(find.text('9999'), findsOneWidget);
    expect(find.text('888'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
