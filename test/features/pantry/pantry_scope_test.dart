import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/widgets/expiry_item_card.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/domain/models/app_notification.dart';
import 'package:food_expiry_and_pantry_management/features/notifications/presentation/widgets/notification_panel.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/pantry_scope.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/active_pantry_scope_provider.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/screens/pantry_items_screen.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/screens/pantry_screen.dart';

void main() {
  test('header and notification wording follow the pantry name', () {
    expect(const PantryScope.personal().headerLabel, 'My Pantry • Personal');
    expect(
      const PantryScope.personal().notificationTitle('Milk is running low'),
      'My Pantry • Milk is running low',
    );
    expect(
      const PantryScope.personal().notificationTitle('Milk expires in 2 days'),
      'My Pantry • Milk expires in 2 days',
    );

    expect(const PantryScope.shared().headerLabel, 'Home Pantry • Shared');
    expect(
      const PantryScope.shared().notificationTitle('Milk is running low'),
      'Home • Milk is running low',
    );
    expect(
      const PantryScope.shared().notificationTitle('Milk expires tomorrow'),
      'Home • Milk expires tomorrow',
    );

    const named = PantryScope.shared('Smith Home');
    expect(named.headerLabel, 'Smith Home • Shared');
    expect(
      named.notificationTitle('Milk expires tomorrow'),
      'Smith Home • Milk expires tomorrow',
    );
    expect(named.badgeLabel, 'Smith Home');
  });

  test('profile types map family and shared, and ignore unknown notification values', () {
    expect(
      PantryScope.fromProfile(pantryType: 'personal').headerLabel,
      'My Pantry • Personal',
    );
    expect(
      PantryScope.fromProfile(
        pantryType: 'family',
        pantryName: 'Family Home',
      ).headerLabel,
      'Family Home • Shared',
    );
    expect(
      PantryScope.fromProfile(pantryType: 'shared').notificationPrefix,
      'Home',
    );
    expect(PantryScope.tryParse(null, null), isNull);
    expect(PantryScope.tryParse('office', null), isNull);
  });

  testWidgets('pantry header follows the active scope in light and dark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pump(ThemeData theme, PantryScope scope) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('${theme.brightness.name}-${scope.headerLabel}'),
          overrides: [
            pantryItemsProvider.overrideWith(_EmptyPantry.new),
            activePantryScopeProvider.overrideWith(
              (ref) => Stream.value(scope),
            ),
          ],
          child: MaterialApp(theme: theme, home: const PantryScreen()),
        ),
      );
      await tester.pump();
    }

    await pump(AppTheme.light, const PantryScope.personal());
    expect(find.text('My Pantry • Personal'), findsOneWidget);

    await pump(AppTheme.light, const PantryScope.shared('Smith Home'));
    expect(find.text('Smith Home • Shared'), findsOneWidget);
    expect(find.text('My Pantry • Personal'), findsNothing);

    await pump(AppTheme.light, const PantryScope.personal());
    expect(find.text('My Pantry • Personal'), findsOneWidget);
    expect(find.text('Smith Home • Shared'), findsNothing);

    await pump(AppTheme.dark, const PantryScope.shared());
    expect(find.text('Home Pantry • Shared'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all items keeps a small scope line', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_EmptyPantry.new),
          activePantryScopeProvider.overrideWith(
            (ref) => Stream.value(const PantryScope.shared('Family Home')),
          ),
        ],
        child: const MaterialApp(home: PantryItemsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('All Pantry Items'), findsOneWidget);
    expect(find.text('Family Home • Shared'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiry card shows the item pantry, not another screen mode', (
    tester,
  ) async {
    final item = PantryItem(
      id: 'milk',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      expiryDate: DateTime(2026, 10, 7),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpiryItemCard(
            item: item,
            message: 'Expires in 2 days',
            urgency: ExpiryCardUrgency.soon,
            scope: const PantryScope.shared(),
            onUpdate: () {},
            onStopTracking: () {},
          ),
        ),
      ),
    );
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Shared'), findsOneWidget);
    expect(find.textContaining('Expires in 2 days'), findsOneWidget);
    expect(find.text('Personal'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ExpiryItemCard(
            item: item,
            message: 'Expires in 2 days',
            urgency: ExpiryCardUrgency.soon,
            onUpdate: () {},
            onStopTracking: () {},
          ),
        ),
      ),
    );
    expect(find.text('Shared'), findsNothing);
    expect(find.text('Personal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a stored shared alert stays shared while the open pantry is personal',
    (tester) async {
      final notification = AppNotification(
        id: 'low',
        userId: 'alice',
        type: AppNotificationType.lowStock,
        title: 'Milk is running low',
        message: 'Only 1 bottle remains.',
        alertKey: 'low',
        pantryScope: 'shared',
        isRead: true,
        createdAt: DateTime(2026, 10, 5, 9),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activePantryScopeProvider.overrideWith(
              (ref) => Stream.value(const PantryScope.personal()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: NotificationTile(notification: notification)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Home • Milk is running low'), findsOneWidget);
      expect(find.text('My Pantry • Milk is running low'), findsNothing);

      final legacy = notification.copyWith();
      expect(legacy.pantryScope, 'shared');
    },
  );
}

class _EmptyPantry extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => Stream.value(const []);
}
