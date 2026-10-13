import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/providers/theme_mode_provider.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/settings/presentation/widgets/low_stock_suggestion_settings_card.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/low_stock_suggestion_settings.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/low_stock_suggestion_settings_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_firestore.dart';

void main() {
  late ShoppingTestSession session;
  late SharedPreferences preferences;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    session = ShoppingTestSession();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
      ],
    );
    container.listen(lowStockSuggestionSettingsProvider, (_, _) {});
    await container.read(shoppingAuthUidProvider.future);
    await container.pump();
  });

  tearDown(() async {
    container.dispose();
    await session.changes.close();
  });

  test('missing settings use enabled, safe centralized defaults', () {
    final settings = container.read(lowStockSuggestionSettingsProvider);
    expect(settings.enabled, isTrue);
    expect(settings.thresholds.keys.toSet(), PantryCategory.values.toSet());
    expect(settings.thresholds.values, everyElement(1));
  });

  test(
    'master and category settings persist across provider recreation',
    () async {
      final notifier = container.read(
        lowStockSuggestionSettingsProvider.notifier,
      );
      notifier.setEnabled(false);
      notifier.setThreshold(PantryCategory.dairy, 7);
      await Future<void>.delayed(Duration.zero);

      final restored = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
        ],
      );
      addTearDown(restored.dispose);
      restored.listen(lowStockSuggestionSettingsProvider, (_, _) {});
      await restored.read(shoppingAuthUidProvider.future);
      await restored.pump();

      final settings = restored.read(lowStockSuggestionSettingsProvider);
      expect(settings.enabled, isFalse);
      expect(settings.thresholdFor(PantryCategory.dairy), 7);
      expect(settings.thresholdFor(PantryCategory.fruits), 1);
    },
  );

  test('settings are isolated by signed-in user', () async {
    container
        .read(lowStockSuggestionSettingsProvider.notifier)
        .setThreshold(PantryCategory.dairy, 4);
    await Future<void>.delayed(Duration.zero);

    session.changeUser('bob');
    await container.pump();
    expect(
      container
          .read(lowStockSuggestionSettingsProvider)
          .thresholdFor(PantryCategory.dairy),
      1,
    );
    container
        .read(lowStockSuggestionSettingsProvider.notifier)
        .setThreshold(PantryCategory.dairy, 9);
    await Future<void>.delayed(Duration.zero);

    session.changeUser('alice');
    await container.pump();
    expect(
      container
          .read(lowStockSuggestionSettingsProvider)
          .thresholdFor(PantryCategory.dairy),
      4,
    );
  });

  test(
    'reset restores category defaults without changing master toggle',
    () async {
      final notifier = container.read(
        lowStockSuggestionSettingsProvider.notifier,
      );
      notifier.setEnabled(false);
      notifier.setThreshold(PantryCategory.dairy, 4);
      notifier.setThreshold(PantryCategory.fruits, 3);
      await notifier.resetThresholds();

      final settings = container.read(lowStockSuggestionSettingsProvider);
      expect(settings.enabled, isFalse);
      expect(settings.thresholds.values, everyElement(1));

      final restored = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
        ],
      );
      addTearDown(restored.dispose);
      restored.listen(lowStockSuggestionSettingsProvider, (_, _) {});
      await restored.read(shoppingAuthUidProvider.future);
      await restored.pump();
      expect(
        restored.read(lowStockSuggestionSettingsProvider).thresholds.values,
        everyElement(1),
      );
      expect(
        restored.read(lowStockSuggestionSettingsProvider).enabled,
        isFalse,
      );
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'settings card works on a narrow ${dark ? 'dark' : 'light'} display',
      (tester) async {
        var settings = LowStockSuggestionSettings();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) =>
                        LowStockSuggestionSettingsCard(
                          settings: settings,
                          onEnabledChanged: (enabled) => setState(
                            () =>
                                settings = settings.copyWith(enabled: enabled),
                          ),
                          onThresholdChanged: (category, threshold) => setState(
                            () => settings = settings.copyWith(
                              category: category,
                              threshold: threshold,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Low Stock Suggestions'), findsOneWidget);
        expect(find.text('Beverages'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(Switch));
        await tester.pump();
        final increase = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Increase Dairy low-stock level'),
            matching: find.byType(IconButton),
          ),
        );
        expect(increase.onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
