import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_list_tile.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_items_sliver.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_view_mode_toggle.dart';

PantryItem _sampleItem({
  String id = '1',
  String name = 'Milk',
  double quantity = 2,
  bool isLowStock = false,
  bool isOutOfStock = false,
}) {
  return PantryItem(
    id: id,
    firestoreId: id,
    name: name,
    category: PantryCategory.dairy,
    location: PantryLocation.refrigerator,
    quantity: isOutOfStock ? 0 : (isLowStock ? 0.5 : quantity),
    unit: PantryUnit.bottles,
    expiryDate: DateTime.now().add(const Duration(days: 2)),
  );
}

void main() {
  testWidgets('PantryItemCard renders 2-column grid visual layout details',
      (tester) async {
    final item = _sampleItem(isLowStock: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 224,
            child: PantryItemCard(
              item: item,
              onEdit: () {},
              onUsedUp: () {},
              onDelete: () {},
              onIncrement: () {},
              onDecrement: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Dairy • Refrigerator'), findsOneWidget);
    expect(find.text('Low stock'), findsOneWidget);
    expect(find.byIcon(Icons.local_drink_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
  });

  testWidgets('PantryItemListTile renders compact horizontal list row details',
      (tester) async {
    final item = _sampleItem();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 84,
            child: PantryItemListTile(
              item: item,
              onEdit: () {},
              onUsedUp: () {},
              onDelete: () {},
              onIncrement: () {},
              onDecrement: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Dairy • Refrigerator'), findsOneWidget);
    expect(find.text('Qty: 2'), findsOneWidget);
    expect(find.byIcon(Icons.local_drink_rounded), findsOneWidget);
  });

  testWidgets('PantryViewModeToggle updates provider immediately',
      (tester) async {
    late ProviderContainer container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(),
        child: const MaterialApp(
          home: Scaffold(
            body: PantryViewModeToggle(),
          ),
        ),
      ),
    );

    expect(container.read(pantryViewModeProvider), PantryViewMode.cards);

    // Tap list view toggle button
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pump();

    expect(container.read(pantryViewModeProvider), PantryViewMode.list);

    // Tap grid view toggle button
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pump();

    expect(container.read(pantryViewModeProvider), PantryViewMode.cards);
  });

  testWidgets('PantryItemsSliver renders Grid in Card mode and SliverList in List mode',
      (tester) async {
    final items = [_sampleItem(id: '1', name: 'Milk'), _sampleItem(id: '2', name: 'Cheese')];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                PantryItemsSliver(items: items, viewMode: PantryViewMode.cards),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(PantryItemCard), findsNWidgets(2));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                PantryItemsSliver(items: items, viewMode: PantryViewMode.list),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byType(PantryItemListTile), findsNWidgets(2));
  });
}
