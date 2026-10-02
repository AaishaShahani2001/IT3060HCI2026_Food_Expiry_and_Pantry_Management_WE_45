import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_form.dart';

void main() {
  testWidgets('the pantry form cannot submit twice', (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    final item = PantryItem(
      id: 'milk',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      price: 450,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PantryItemForm(
              initialItem: item,
              onSubmit: (_) async {
                calls++;
                await gate.future;
              },
            ),
          ),
        ),
      ),
    );

    final button = find.widgetWithText(FilledButton, 'Update item');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(calls, 1);
    expect(find.bySemanticsLabel('Saving item…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });
}
