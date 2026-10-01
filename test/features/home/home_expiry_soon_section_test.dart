import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_expiry_soon_section.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/screens/pantry_item_details_screen.dart';
import 'package:go_router/go_router.dart';

List<PantryItem> _items = const [];

class _ScriptedPantryItemsNotifier extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => Stream.value(_items);
}

class _FailingPantryItemsNotifier extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => throw Exception('offline');
}

PantryItem _item({
  required String id,
  required String name,
  DateTime? expiryDate,
}) {
  return PantryItem(
    id: id,
    firestoreId: id,
    name: name,
    category: PantryCategory.dairy,
    location: PantryLocation.refrigerator,
    quantity: 1,
    unit: PantryUnit.items,
    expiryDate: expiryDate,
  );
}

DateTime _day(int offset) {
  final today = DateTime.now();
  return DateTime(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: offset));
}

void main() {
  setUp(() {
    _items = const [];
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    required PantryItemsNotifier Function() notifier,
    Size size = const Size(400, 800),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: HomeExpirySoonSection(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.expiry,
          builder: (context, state) =>
              const Scaffold(body: Text('Expiry destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [pantryItemsProvider.overrideWith(notifier)],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows nearest expiring items and hides expired or fresh ones', (
    tester,
  ) async {
    _items = [
      _item(id: 'fresh', name: 'Rice', expiryDate: _day(10)),
      _item(id: 'later', name: 'Cheese', expiryDate: _day(3)),
      _item(id: 'expired', name: 'Bread', expiryDate: _day(-2)),
      _item(id: 'soon', name: 'Milk', expiryDate: _day(1)),
      _item(id: 'today', name: 'Yogurt', expiryDate: _day(0)),
    ];

    await pumpSection(tester, notifier: _ScriptedPantryItemsNotifier.new);

    expect(find.text('Expiry Soon'), findsOneWidget);
    expect(find.text('Yogurt'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Cheese'), findsOneWidget);
    expect(find.text('Expires today'), findsOneWidget);
    expect(find.text('1 day left'), findsOneWidget);
    expect(find.text('3 days left'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    expect(find.text('Bread'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Yogurt')).dx,
      lessThan(tester.getTopLeft(find.text('Milk')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Milk')).dx,
      lessThan(tester.getTopLeft(find.text('Cheese')).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('See All opens the existing expiry screen', (tester) async {
    _items = [_item(id: 'soon', name: 'Milk', expiryDate: _day(1))];
    await pumpSection(tester, notifier: _ScriptedPantryItemsNotifier.new);

    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();

    expect(find.text('Expiry destination'), findsOneWidget);
  });

  testWidgets('tapping a card opens the existing item details screen', (
    tester,
  ) async {
    _items = [_item(id: 'soon', name: 'Milk', expiryDate: _day(2))];
    await pumpSection(tester, notifier: _ScriptedPantryItemsNotifier.new);

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();

    expect(find.byType(PantryItemDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, error, and narrow layouts stay compact', (tester) async {
    await pumpSection(tester, notifier: _ScriptedPantryItemsNotifier.new);
    expect(find.text('No items expiring soon'), findsOneWidget);

    await pumpSection(
      tester,
      notifier: _FailingPantryItemsNotifier.new,
      size: const Size(320, 700),
    );
    expect(find.text('Couldn’t load expiring items'), findsOneWidget);
    expect(tester.takeException(), isNull);

    _items = [
      for (var index = 0; index < 6; index++)
        _item(id: 'item-$index', name: 'Item $index', expiryDate: _day(index)),
    ];
    await pumpSection(
      tester,
      notifier: _ScriptedPantryItemsNotifier.new,
      size: const Size(320, 700),
      theme: AppTheme.dark,
    );
    expect(tester.takeException(), isNull);
  });
}
