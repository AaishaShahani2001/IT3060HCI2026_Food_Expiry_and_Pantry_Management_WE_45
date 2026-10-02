import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_image.dart';

void main() {
  PantryItem item(String photoUrl) {
    return PantryItem(
      id: 'milk',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      photoUrl: photoUrl,
    );
  }

  testWidgets('legacy Firebase image URLs still render', (tester) async {
    const firebaseUrl =
        'https://firebasestorage.googleapis.com/v0/b/app/o/milk.jpg?alt=media';

    await tester.pumpWidget(
      MaterialApp(
        home: PantryItemImage(item: item(firebaseUrl), width: 80, height: 80),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, firebaseUrl);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('a failed Cloudinary image shows the category placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantryItemImage(
          item: item(
            'https://res.cloudinary.com/test-cloud/image/upload/v1/missing.jpg',
          ),
          width: 80,
          height: 80,
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(PantryCategory.dairy.icon), findsOneWidget);
    expect(find.byIcon(Icons.broken_image), findsNothing);
  });
}
