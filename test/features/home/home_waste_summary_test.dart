import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/providers/current_user_provider.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/home_screen.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_waste_summary_card.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/summary_card.dart';
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

  String value(WidgetTester tester) => tester
      .widget<SummaryCard>(find.byKey(const ValueKey('home-waste-summary')))
      .value;
  Future<void> openWaste(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(HomeWasteSummaryCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HomeWasteSummaryCard));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Home uses matching summary card after Shopping and before Recipes with empty state',
    (tester) async {
      await open(tester);
      expect(
        tester
            .widgetList<SummaryCard>(find.byType(SummaryCard))
            .map((c) => c.title),
        [
          AppStrings.pantryItems,
          AppStrings.expiringSoon,
          AppStrings.shoppingList,
          'Waste Tracker',
          AppStrings.recipeSuggestions,
        ],
      );
      expect(value(tester), 'No waste recorded yet');
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('weekly count and value exclude old records and other users', (
    tester,
  ) async {
    session.seed('alice', 'a', draft(value: 100));
    session.seed('alice', 'b', draft(value: 250, date: DateTime(2026, 9, 14)));
    session.seed(
      'alice',
      'old',
      draft(value: 999, date: DateTime(2026, 9, 13)),
    );
    session.seed('bob', 'private', draft(value: 5000));
    await open(tester);
    expect(value(tester), '2 items wasted\nRs. 350.00 this week');
    expect(session.store.readCalls, 1);
  });

  testWidgets('older history does not falsely imply no waste ever recorded', (
    tester,
  ) async {
    session.seed('alice', 'old', draft(date: DateTime(2026, 9, 1)));
    await open(tester);
    expect(value(tester), 'No waste recorded this week');
  });

  testWidgets('loading is confined to the card and does not block Home', (
    tester,
  ) async {
    final gate = Completer<void>();
    session.store.readGate = gate.future;
    await open(tester, settle: false);
    await tester.pump();
    await tester.pump();
    expect(value(tester), 'Loading waste summary...');
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text(AppStrings.pantryItems), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(value(tester), 'No waste recorded yet');
  });

  testWidgets(
    'read error keeps card tappable and opens dedicated error/retry screen',
    (tester) async {
      session.store.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'PRIVATE DETAILS',
      );
      await open(tester);
      expect(value(tester), 'Tap to view');
      expect(find.text('PRIVATE DETAILS'), findsNothing);
      await openWaste(tester);
      expect(find.byType(WasteTrackerScreen), findsOneWidget);
      expect(
        find.text(
          'Permission denied for waste records. Please contact the team.',
        ),
        findsOneWidget,
      );
      session.store.readError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(value(tester), 'No waste recorded yet');
    },
  );

  testWidgets(
    'rebuild and opening tracker reuse records; edits refresh Home summary',
    (tester) async {
      session.seed('alice', 'a', draft(value: 100));
      await open(tester);
      for (var i = 0; i < 3; i++) {
        rebuild.value++;
        await tester.pumpAndSettle();
      }
      expect(session.store.readCalls, 1);
      await openWaste(tester);
      expect(session.store.readCalls, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WasteTrackerScreen)),
      );
      await tester.runAsync(
        () =>
            container.read(foodWasteProvider.notifier).save(draft(value: 250)),
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(value(tester), '2 items wasted\nRs. 350.00 this week');
      expect(session.store.readCalls, 1);
    },
  );

  testWidgets(
    'account changes and logout clear old summary including during pending reads',
    (tester) async {
      session.seed('alice', 'a', draft(value: 100));
      session.seed('bob', 'b', draft(value: 25));
      await open(tester);
      expect(value(tester), contains('Rs. 100.00'));
      final gate = Completer<void>();
      session.store.readGate = gate.future;
      session.changeUser('bob');
      await tester.pump();
      await tester.pump();
      expect(value(tester), isNot(contains('100.00')));
      gate.complete();
      session.store.readGate = null;
      await tester.pumpAndSettle();
      expect(value(tester), '1 item wasted\nRs. 25.00 this week');
      session.changeUser(null);
      await tester.pumpAndSettle();
      expect(value(tester), 'Tap to view');
    },
  );

  testWidgets(
    'large counts and currency at narrow width and large text have no overflow',
    (tester) async {
      for (var i = 0; i < 1000; i++) {
        session.seed('alice', '$i', draft(value: 987654321.25));
      }
      await open(tester, size: const Size(320, 700), scale: 2);
      await tester.ensureVisible(find.byType(HomeWasteSummaryCard));
      await tester.pumpAndSettle();
      expect(value(tester), '1000 items wasted\nRs. 987654321250.00 this week');
      expect(tester.takeException(), isNull);
    },
  );
}
