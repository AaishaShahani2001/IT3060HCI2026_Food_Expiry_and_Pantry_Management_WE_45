import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/screens/expiry_screen.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/widgets/expiry_summary_card.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/utils/expiry_status.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';

List<PantryItem> _pantryItems = const [];

class _ScriptedPantryItemsNotifier extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => Stream.value(_pantryItems);
}

class _LoadingPantryItemsNotifier extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() {
    final controller = StreamController<List<PantryItem>>();
    ref.onDispose(controller.close);
    return controller.stream;
  }
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

  testWidgets('summary cards use live counts and filter the existing list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final calendarDay = DateTime(today.year, today.month, today.day);
    _pantryItems = [
      _item(
        id: 'expired',
        name: 'Bread',
        expiryDate: calendarDay.subtract(const Duration(days: 1)),
      ),
      _item(id: 'today', name: 'Milk', expiryDate: calendarDay),
      _item(
        id: 'soon',
        name: 'Cheese',
        expiryDate: calendarDay.add(const Duration(days: 3)),
      ),
      _item(
        id: 'fresh',
        name: 'Yogurt',
        expiryDate: calendarDay.add(const Duration(days: 4)),
      ),
      _item(id: 'rice', name: 'Rice'),
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

    expect(find.text('ALERT'), findsOneWidget);
    expect(_cardText('expiry-summary-expiring-soon', 'SOON'), findsOneWidget);
    expect(find.text('SAFE'), findsOneWidget);
    expect(find.text('PANTRY'), findsOneWidget);
    expect(_cardText('expiry-summary-expired', 'Expired'), findsOneWidget);
    expect(
      _cardText('expiry-summary-expiring-soon', 'Expiring Soon'),
      findsOneWidget,
    );
    expect(_cardText('expiry-summary-fresh', 'Fresh / Safe'), findsOneWidget);
    expect(_cardText('expiry-summary-no-expiry', 'No Expiry'), findsOneWidget);
    expect(find.text('Within ${kExpiryExpiringSoonDays}d'), findsOneWidget);

    expect(_cardText('expiry-summary-expired', '1 item'), findsOneWidget);
    expect(
      _cardText('expiry-summary-expiring-soon', '2 items'),
      findsOneWidget,
    );
    expect(_cardText('expiry-summary-fresh', '1 item'), findsOneWidget);
    expect(_cardText('expiry-summary-no-expiry', '1 item'), findsOneWidget);

    expect(
      _cardIcon('expiry-summary-expired', Icons.event_busy_outlined),
      findsOneWidget,
    );
    expect(
      _cardIcon('expiry-summary-expiring-soon', Icons.upcoming_outlined),
      findsOneWidget,
    );
    expect(
      _cardIcon('expiry-summary-fresh', Icons.event_available_outlined),
      findsOneWidget,
    );
    expect(
      _cardIcon('expiry-summary-no-expiry', Icons.calendar_month_outlined),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            _cardIcon('expiry-summary-fresh', Icons.event_available_outlined),
          )
          .size,
      52,
    );

    final expiredCard = tester.getRect(
      find.byKey(const ValueKey('expiry-summary-expired')),
    );
    final soonCard = tester.getRect(
      find.byKey(const ValueKey('expiry-summary-expiring-soon')),
    );
    final freshCard = tester.getRect(
      find.byKey(const ValueKey('expiry-summary-fresh')),
    );
    expect((expiredCard.top - soonCard.top).abs(), lessThan(2));
    expect(expiredCard.left, lessThan(soonCard.left));
    expect(freshCard.top, greaterThan(expiredCard.bottom - 1));

    expect(
      tester.getTopLeft(find.text('ALERT')).dy,
      lessThan(tester.getTopLeft(find.text('Track Item Expiry')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Track Waste')).dy,
      lessThan(tester.getTopLeft(find.text('Fresh 1')).dy),
    );

    expect(find.text('Rice'), findsNothing);
    expect(find.text('Yogurt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('expiry-summary-expired')));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Yogurt'), findsNothing);
    expect(find.text('Rice'), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('expiry-summary-expired'))),
      matchesSemantics(
        label: 'Show 1 expired item',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('expiry-summary-expired')));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Yogurt'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('expiry-summary-no-expiry')));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Bread'), findsNothing);
    expect(find.text('Yogurt'), findsNothing);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('expiry-summary-no-expiry')),
      ),
      matchesSemantics(
        label: 'Show 1 item with no expiry date',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
      ),
    );

    final expiredFill = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const ValueKey('expiry-summary-expired')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(expiredFill.color, isNot(AppColors.statusRed));
    expect(expiredFill.clipBehavior, Clip.antiAlias);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary cards stay one column on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSection(tester, width: 280);

    final alert = tester.getRect(
      find.byKey(const ValueKey('expiry-summary-expired')),
    );
    final soon = tester.getRect(
      find.byKey(const ValueKey('expiry-summary-expiring-soon')),
    );
    expect(soon.top, greaterThan(alert.bottom - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary cards use one row when the width allows four', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSection(tester, width: 760);

    final tops = [
      tester.getRect(find.byKey(const ValueKey('expiry-summary-expired'))).top,
      tester
          .getRect(find.byKey(const ValueKey('expiry-summary-expiring-soon')))
          .top,
      tester.getRect(find.byKey(const ValueKey('expiry-summary-fresh'))).top,
      tester
          .getRect(find.byKey(const ValueKey('expiry-summary-no-expiry')))
          .top,
    ];
    expect(tops.toSet().length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text scaling does not overflow the summary cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            );
          },
          home: const ExpiryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final alert = tester.getRect(
      find.byKey(const ValueKey('expiry-summary-expired')),
    );
    final soon = tester.getRect(
      find.byKey(const ValueKey('expiry-summary-expiring-soon')),
    );
    expect(soon.top, greaterThan(alert.bottom - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and error states do not show zero summary counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_LoadingPantryItemsNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ExpiryScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('ALERT'), findsNothing);
    expect(find.text('0 items'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expiry load error does not show summary counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          pantryItemsProvider.overrideWith(_FailingPantryItemsNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ExpiryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to load expiry items'), findsOneWidget);
    expect(find.text('ALERT'), findsNothing);
    expect(find.text('0 items'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary cards stay readable in dark theme', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryItemsProvider.overrideWith(_ScriptedPantryItemsNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const ExpiryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNot(AppColors.cream));

    final expiredFill = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const ValueKey('expiry-summary-expired')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(expiredFill.color, isNot(AppColors.statusRed));
    expect(
      ThemeData.estimateBrightnessForColor(expiredFill.color!),
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _cardText(String key, String text) {
  return find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.text(text),
  );
}

Finder _cardIcon(String key, IconData icon) {
  return find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byIcon(icon),
  );
}

Future<void> _pumpSection(WidgetTester tester, {required double width}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: ExpirySummarySection(
              expiredCount: 2,
              expiringSoonCount: 3,
              freshCount: 8,
              noExpiryCount: 1,
              selectedFilter: ExpiryStatusFilter.all,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}
