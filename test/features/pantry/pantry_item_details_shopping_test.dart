import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/screens/pantry_item_details_screen.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';

import '../shopping_list/support/fake_firestore.dart';

PantryItem milk() {
  return const PantryItem(
    id: 'milk',
    firestoreId: 'milk',
    name: 'Milk',
    category: PantryCategory.beverages,
    location: PantryLocation.refrigerator,
    quantity: 2,
    unit: PantryUnit.bottles,
  );
}

class _SeedPantry extends PantryItemsNotifier {
  _SeedPantry(this.items);

  final List<PantryItem> items;

  @override
  Stream<List<PantryItem>> build() => Stream.value(items);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'item details adds the pantry item to the shopping list',
    (tester) async {
      final session = ShoppingTestSession();
      addTearDown(session.changes.close);
      final item = milk();
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pantryItemsProvider.overrideWith(() => _SeedPantry([item])),
            shoppingListRepositoryProvider.overrideWithValue(
              session.repository,
            ),
            shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(shoppingListProvider);
                return PantryItemDetailsScreen(item: item);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add shopping list'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add shopping list'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Milk added to your shopping list'), findsOneWidget);
      final saved = session.store.documents.values.single;
      expect(saved['name'], 'Milk');
      expect(saved['quantity'], 2);
      expect(saved['unit'], PantryUnit.bottles.name);
      expect(saved['isPurchased'], isFalse);
      expect(saved['sourcePantryItemId'], 'milk');

      await tester.ensureVisible(find.text('Add shopping list'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add shopping list'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Milk is already on your shopping list'), findsOneWidget);
      expect(session.store.documents, hasLength(1));
    },
  );
}
