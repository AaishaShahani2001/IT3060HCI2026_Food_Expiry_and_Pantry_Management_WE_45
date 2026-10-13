import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/providers/current_user_provider.dart';
import 'package:food_expiry_and_pantry_management/core/providers/theme_mode_provider.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/settings/presentation/screens/low_stock_suggestion_settings_screen.dart';
import 'package:food_expiry_and_pantry_management/features/settings/presentation/screens/settings_screen.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<GoRouter> openSettings(
    WidgetTester tester, {
    Map<String, Object> storedValues = const {},
    bool dark = false,
    Size size = const Size(430, 900),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(storedValues);
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.lowStockSuggestions,
          builder: (context, state) => const LowStockSuggestionSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          shoppingAuthUidProvider.overrideWith((ref) => Stream.value('alice')),
          currentUserNameProvider.overrideWithValue(
            const AsyncData('Test user'),
          ),
          settingsUserEmailProvider.overrideWithValue('alice@example.com'),
        ],
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark : AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('main Settings shows compact tile and opens detail screen', (
    tester,
  ) async {
    await openSettings(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Low Stock Suggestions'), findsOneWidget);
    expect(
      find.text('Control shopping suggestions and stock thresholds'),
      findsOneWidget,
    );
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Category Thresholds'), findsNothing);
    expect(find.byTooltip('Increase Dairy low-stock level'), findsNothing);

    await tester.tap(find.text('Low Stock Suggestions'));
    await tester.pumpAndSettle();
    expect(find.byType(LowStockSuggestionSettingsScreen), findsOneWidget);
    expect(find.text('Category Thresholds'), findsOneWidget);
    expect(find.byTooltip('Increase Dairy low-stock level'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Low Stock Suggestions'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets(
    'tile shows Off and detail controls remain visible but disabled',
    (tester) async {
      await openSettings(
        tester,
        storedValues: const {'low_stock_suggestions.alice.enabled': false},
      );

      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.text('Low Stock Suggestions'));
      await tester.pumpAndSettle();

      final increase = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Increase Dairy low-stock level'),
          matching: find.byType(IconButton),
        ),
      );
      expect(increase.onPressed, isNull);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Increase Dairy low-stock level'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('Reset requires confirmation and preserves the master toggle', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('Low Stock Suggestions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase Dairy low-stock level'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.ensureVisible(find.text('Reset to Defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to Defaults'));
    await tester.pumpAndSettle();
    expect(find.text('Reset low-stock settings?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.ensureVisible(find.text('Reset to Defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to Defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing);
    expect(
      find.text('Low-stock suggestion levels reset to defaults.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'detail screen supports narrow large-text ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        final router = await openSettings(
          tester,
          dark: dark,
          size: const Size(320, 900),
          textScale: 2,
        );
        router.push(AppRoutes.lowStockSuggestions);
        await tester.pumpAndSettle();

        expect(find.byType(LowStockSuggestionSettingsScreen), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
        expect(find.text('Reset to Defaults'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
