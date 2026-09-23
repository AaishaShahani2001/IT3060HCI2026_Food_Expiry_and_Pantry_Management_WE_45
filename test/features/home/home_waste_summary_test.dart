import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/pantry_waste_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:food_expiry_and_pantry_management/core/providers/current_user_provider.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/home_screen.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_waste_summary_card.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/waste_tracker_screen.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_provider.dart';
import '../food_waste_tracking/support/waste_test_session.dart';

class _TestUserName extends CurrentUserNameNotifier {
  @override
  Future<String> build() async => 'Test user';
}

void main() {
  late WasteTestSession session;
  late GoRouter router;
  late ValueNotifier<int> rebuild;

  setUp(() {
    session = WasteTestSession();
    rebuild = ValueNotifier(0);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (_, value, _) => HomeScreen(key: ValueKey(value)),
          ),
        ),
        GoRoute(
          path: '/waste-tracker',
          builder: (_, _) => const WasteTrackerScreen(),
        ),
      ],
    );
  });

  Future<void> open(
    WidgetTester tester, {
    bool settle = true,
    Size size = const Size(430, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      rebuild.dispose();
      await session.changes.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserNameProvider.overrideWith(_TestUserName.new),
          pantrySummaryProvider.overrideWithValue((total: 2, lowStock: 0)),
          expirySummaryProvider.overrideWithValue((
            total: 2,
            expired: 0,
            expiringSoon: 1,
            fresh: 1,
            unknown: 0,
          )),
          foodWasteRepositoryProvider.overrideWithValue(session.repository),
          wastePantryServiceProvider.overrideWithValue(session.pantry),
          wasteAuthUidProvider.overrideWith((ref) => session.auth()),
          wasteClockProvider.overrideWithValue(() => wasteTestNow),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
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
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> openWaste(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(HomeWasteSummaryCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HomeWasteSummaryCard));
    await tester.pumpAndSettle();
  }

  testWidgets('Home displays This Month Waste Tracker card directly below My Profile', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(HomeWasteSummaryCard), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('View All'), findsOneWidget);
    expect(find.text('Food Wasted'), findsOneWidget);
    expect(find.text('Estimated Loss'), findsOneWidget);
  });

  testWidgets('Monthly count and estimated loss display active user records', (
    tester,
  ) async {
    session.seed('alice', 'a', draft(value: 1000));
    session.seed('alice', 'b', draft(value: 3000, date: DateTime(2026, 9, 14)));
    session.seed('bob', 'private', draft(value: 5000));
    await open(tester);

    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Rs. 4,000'), findsOneWidget);
  });

  testWidgets('Tapping View All or Card navigates to waste tracker screen', (
    tester,
  ) async {
    await open(tester);
    await openWaste(tester);
    expect(find.byType(WasteTrackerScreen), findsOneWidget);
  });

  testWidgets(
    'large counts and currency at narrow width and large text have no overflow',
    (tester) async {
      for (var i = 0; i < 1000; i++) {
        session.seed('alice', '$i', draft(value: 987654321.25));
      }
      await open(tester, size: const Size(320, 700), scale: 2);
      await tester.ensureVisible(find.byType(HomeWasteSummaryCard));
      await tester.pumpAndSettle();
      expect(find.text('1000 items'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

