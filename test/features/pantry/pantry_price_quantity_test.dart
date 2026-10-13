import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/repositories/mock_pantry_repository.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/utils/pantry_price_display.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_form.dart';

PantryItem _item({
  double quantity = 1,
  double? originalQuantity,
  PantryUnit unit = PantryUnit.bottles,
  double? priceAmount,
  PantryPriceType? priceType,
  String? photoUrl,
}) {
  return PantryItem(
    id: 'milk',
    firestoreId: 'milk',
    name: 'Milk',
    category: PantryCategory.dairy,
    location: PantryLocation.refrigerator,
    quantity: quantity,
    originalQuantity: originalQuantity,
    unit: unit,
    priceAmount: priceAmount,
    priceType: priceType,
    photoUrl: photoUrl,
    imagePublicId: photoUrl == null ? null : 'freshtrack/pantry/uid/milk',
    imageProvider: photoUrl == null ? null : 'cloudinary',
    expiryDate: DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 9, 1),
  );
}

void main() {
  test('a new item keeps the entered quantity as the original quantity', () {
    final item = _item(quantity: 2, priceAmount: 800);

    expect(item.originalQuantity, 2);
    expect(item.quantity, 2);
  });

  test('quantity controls change only the remaining quantity', () {
    final item = _item(
      quantity: 2,
      originalQuantity: 2,
      priceAmount: 800,
      priceType: PantryPriceType.totalPrice,
    );

    final reduced = item.withAdjustedQuantity(-1);

    expect(reduced.quantity, 1);
    expect(reduced.originalQuantity, 2);
    expect(reduced.priceAmount, 800);
    expect(reduced.priceType, PantryPriceType.totalPrice);
    expect(reduced.estimatedRemainingValue, 400);
  });

  test('editing another field preserves the original quantity', () {
    final item = _item(quantity: 1, originalQuantity: 2, priceAmount: 800);

    final edited = item.copyWith(
      name: 'Fresh milk',
      location: PantryLocation.pantry,
    );

    expect(edited.quantity, 1);
    expect(edited.originalQuantity, 2);
    expect(edited.priceAmount, 800);
  });

  test(
    'measured units suggest unit price and counted units suggest total price',
    () {
      expect(
        PantryPriceType.suggestedFor(PantryUnit.kg),
        PantryPriceType.unitPrice,
      );
      expect(
        PantryPriceType.suggestedFor(PantryUnit.g),
        PantryPriceType.unitPrice,
      );
      expect(
        PantryPriceType.suggestedFor(PantryUnit.liters),
        PantryPriceType.unitPrice,
      );
      expect(
        PantryPriceType.suggestedFor(PantryUnit.ml),
        PantryPriceType.unitPrice,
      );
      expect(
        PantryPriceType.suggestedFor(PantryUnit.items),
        PantryPriceType.totalPrice,
      );
      expect(
        PantryPriceType.suggestedFor(PantryUnit.packs),
        PantryPriceType.totalPrice,
      );
      expect(
        PantryPriceType.suggestedFor(PantryUnit.bottles),
        PantryPriceType.totalPrice,
      );
      expect(
        PantryPriceType.suggestedFor(PantryUnit.boxes),
        PantryPriceType.totalPrice,
      );
    },
  );

  test('1.5 kg at Rs. 400 per kg is Rs. 600', () {
    final item = _item(
      quantity: 1.5,
      originalQuantity: 2,
      unit: PantryUnit.kg,
      priceAmount: 400,
      priceType: PantryPriceType.unitPrice,
    );

    expect(calculateRemainingValue(item), 600);
  });

  test('500 g at Rs. 400 per kg is Rs. 200', () {
    final item = _item(
      quantity: 500,
      unit: PantryUnit.g,
      priceAmount: 400,
      priceType: PantryPriceType.unitPrice,
    );

    expect(calculateRemainingValue(item), 200);
  });

  test('1.5 L uses the price per litre', () {
    final item = _item(
      quantity: 1.5,
      unit: PantryUnit.liters,
      priceAmount: 200,
      priceType: PantryPriceType.unitPrice,
    );

    expect(calculateRemainingValue(item), 300);
  });

  test('500 ml is valued as 0.5 L', () {
    final item = _item(
      quantity: 500,
      unit: PantryUnit.ml,
      priceAmount: 200,
      priceType: PantryPriceType.unitPrice,
    );

    expect(calculateRemainingValue(item), 100);
  });

  test('one bottle left from two at a total of Rs. 800 is Rs. 400', () {
    final item = _item(
      quantity: 1,
      originalQuantity: 2,
      priceAmount: 800,
      priceType: PantryPriceType.totalPrice,
    );

    expect(item.estimatedRemainingValue, 400);
  });

  test('a zero original quantity does not divide by zero', () {
    final item = _item(
      quantity: 1,
      originalQuantity: 0,
      priceAmount: 800,
      priceType: PantryPriceType.totalPrice,
    );

    expect(calculateRemainingValue(item), 0);
  });

  test('negative quantity and price are rejected', () {
    expect(validatePantryQuantity('-1'), 'Quantity must be greater than 0.');
    expect(validatePantryQuantity('NaN'), 'Enter a valid number.');
    expect(validatePantryQuantity('Infinity'), 'Enter a valid number.');
    expect(
      validatePantryPrice(
        '-5',
        unit: PantryUnit.kg,
        type: PantryPriceType.unitPrice,
      ),
      'Enter a valid price per kg.',
    );
    expect(
      validatePantryPrice(
        'NaN',
        unit: PantryUnit.bottles,
        type: PantryPriceType.totalPrice,
      ),
      'Enter a valid total price.',
    );
  });

  test('a missing price is worth zero', () {
    final item = _item(quantity: 2, originalQuantity: 2);

    expect(item.priceAmount, isNull);
    expect(item.hasPrice, isFalse);
    expect(calculateRemainingValue(item), 0);
  });

  test('a legacy document is read as a total price', () {
    final item = PantryItem.fromMap('rice', {
      'name': 'Rice',
      'category': 'grains',
      'location': 'pantry',
      'quantity': 2,
      'unit': 'kg',
      'price': 800,
    });

    expect(item.originalQuantity, 2);
    expect(item.quantity, 2);
    expect(item.priceType, PantryPriceType.totalPrice);
    expect(item.priceAmount, 800);
    expect(item.estimatedRemainingValue, 800);
  });

  test('integer Firestore numbers become doubles', () {
    final item = PantryItem.fromMap('rice', {
      'name': 'Rice',
      'quantity': 2,
      'originalQuantity': 2,
      'unit': 'kg',
      'priceType': 'unitPrice',
      'priceAmount': 400,
    });

    expect(item.quantity, 2.0);
    expect(item.originalQuantity, 2.0);
    expect(item.priceAmount, 400.0);
    expect(item.priceAmount, isA<double>());
  });

  test('Used Up and Undo keep original quantity and price data', () async {
    final item = _item(
      quantity: 1,
      originalQuantity: 2,
      priceAmount: 800,
      priceType: PantryPriceType.totalPrice,
      photoUrl: 'https://res.cloudinary.com/demo/image/upload/v1/milk.jpg',
    );
    final repository = MockPantryRepository(initialItems: [item]);

    final removed = await repository.markAsUsedUp(item, originalIndex: 0);

    expect(removed.item.quantity, 1);
    expect(removed.item.originalQuantity, 2);
    expect(removed.item.priceType, PantryPriceType.totalPrice);
    expect(removed.item.priceAmount, 800);
    expect(removed.item.unit, PantryUnit.bottles);
    expect(
      removed.item.photoUrl,
      'https://res.cloudinary.com/demo/image/upload/v1/milk.jpg',
    );
    expect(removed.item.estimatedRemainingValue, 400);

    final restored = await repository.restoreUsedUpItem(removed);
    expect(restored.quantity, 1);
    expect(restored.originalQuantity, 2);
    expect(restored.priceAmount, 800);
    expect(restored.priceType, PantryPriceType.totalPrice);
    expect(restored.estimatedRemainingValue, 400);
  });

  test(
    'restoring the previous remaining quantity restores the estimated value',
    () async {
      final item = _item(
        quantity: 1,
        originalQuantity: 2,
        priceAmount: 800,
        priceType: PantryPriceType.totalPrice,
      );
      final repository = MockPantryRepository(initialItems: [item]);

      await repository.updateQuantity(itemId: 'milk', quantity: 2);
      final increased = (await repository.fetchItems()).single;
      expect(increased.quantity, 2);
      expect(increased.originalQuantity, 2);
      expect(increased.estimatedRemainingValue, 800);

      await repository.updateQuantity(itemId: 'milk', quantity: 1);
      final undone = (await repository.fetchItems()).single;
      expect(undone.quantity, 1);
      expect(undone.originalQuantity, 2);
      expect(undone.priceAmount, 800);
      expect(undone.priceType, PantryPriceType.totalPrice);
      expect(undone.estimatedRemainingValue, 400);
    },
  );

  test('Firestore maps round-trip the new price and quantity fields', () {
    final item = _item(
      quantity: 1.5,
      originalQuantity: 2,
      unit: PantryUnit.kg,
      priceAmount: 400,
      priceType: PantryPriceType.unitPrice,
    );

    final loaded = PantryItem.fromMap(item.id, item.toMap());

    expect(loaded.quantity, 1.5);
    expect(loaded.originalQuantity, 2);
    expect(loaded.unit, PantryUnit.kg);
    expect(loaded.priceType, PantryPriceType.unitPrice);
    expect(loaded.priceAmount, 400);
    expect(loaded.toMap()['price'], 400);
    expect(calculateRemainingValue(loaded), 600);
  });

  testWidgets(
    'changing the unit suggests a price type until the user chooses one',
    (tester) async {
      await _pumpForm(tester);

      expect(_selectedPriceType(tester), PantryPriceType.totalPrice);

      await _selectUnit(tester, 'kg');
      expect(_selectedPriceType(tester), PantryPriceType.unitPrice);

      await tester.tap(find.text('Total Price'));
      await tester.pumpAndSettle();
      await _selectUnit(tester, 'L');

      expect(_selectedPriceType(tester), PantryPriceType.totalPrice);
    },
  );

  testWidgets('editing loads the saved price type', (tester) async {
    await _pumpForm(
      tester,
      item: _item(
        unit: PantryUnit.items,
        priceAmount: 400,
        priceType: PantryPriceType.unitPrice,
      ),
    );

    expect(_selectedPriceType(tester), PantryPriceType.unitPrice);

    await _selectUnit(tester, 'kg');
    expect(_selectedPriceType(tester), PantryPriceType.unitPrice);
  });

  testWidgets('saving a new item stores the entered quantity as the original', (
    tester,
  ) async {
    PantryItemFormData? saved;
    await _pumpForm(tester, onSubmit: (data) async => saved = data);

    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await tester.tap(find.byType(DropdownButtonFormField<PantryCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dairy').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pantry-quantity-field')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pantry-price-field')),
      '800',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save item'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save item'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.quantity, 2);
    expect(saved!.originalQuantity, 2);
    expect(saved!.price, 800);
    expect(saved!.priceType, PantryPriceType.totalPrice);
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  PantryItem? item,
  Future<void> Function(PantryItemFormData data)? onSubmit,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PantryItemForm(
            initialItem: item,
            onSubmit: onSubmit ?? (_) async {},
          ),
        ),
      ),
    ),
  );
}

PantryPriceType _selectedPriceType(WidgetTester tester) {
  final button = tester.widget<SegmentedButton<PantryPriceType>>(
    find.byKey(const ValueKey('pantry-price-type')),
  );
  return button.selected.single;
}

Future<void> _selectUnit(WidgetTester tester, String label) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('pantry-unit-dropdown')),
  );
  await tester.tap(find.byKey(const ValueKey('pantry-unit-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
