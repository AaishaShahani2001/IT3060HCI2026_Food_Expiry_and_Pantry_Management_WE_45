import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';

PantryItem _milk({String? photoUrl, String? photoStoragePath}) {
  return PantryItem(
    id: 'doc-milk',
    firestoreId: 'doc-milk',
    name: 'Milk',
    category: PantryCategory.dairy,
    location: PantryLocation.refrigerator,
    quantity: 2,
    unit: PantryUnit.bottles,
    price: 450,
    photoUrl: photoUrl,
    photoStoragePath: photoStoragePath,
  );
}

void main() {
  test('documents without photo fields still load', () {
    final item = PantryItem.fromFirestore('doc-1', {
      'name': 'Rice',
      'category': 'grains',
      'location': 'pantry',
      'quantity': 1,
      'unit': 'kg',
      'price': 200,
    });

    expect(item.photoUrl, isNull);
    expect(item.photoStoragePath, isNull);
    expect(item.imagePublicId, isNull);
    expect(item.imageProvider, isNull);
    expect(item.hasUserPhoto, isFalse);
  });

  test('fromFirestore reads optional photo fields', () {
    final item = PantryItem.fromFirestore('doc-1', {
      'name': 'Rice',
      'category': 'grains',
      'location': 'pantry',
      'quantity': 1,
      'unit': 'kg',
      'price': 200,
      'photoUrl': 'https://example.com/rice.jpg',
      'photoStoragePath': 'users/uid/pantryItems/doc-1/photo.jpg',
    });

    expect(item.photoUrl, 'https://example.com/rice.jpg');
    expect(item.photoStoragePath, 'users/uid/pantryItems/doc-1/photo.jpg');
    expect(item.hasUserPhoto, isTrue);
  });

  test('copyWith clearPhoto removes URL and storage path', () {
    final item = _milk(
      photoUrl: 'https://example.com/milk.jpg',
      photoStoragePath: 'users/uid/pantryItems/doc-milk/photo.jpg',
    );

    final cleared = item.copyWith(clearPhoto: true);
    expect(cleared.photoUrl, isNull);
    expect(cleared.photoStoragePath, isNull);
    expect(cleared.imagePublicId, isNull);
    expect(cleared.imageProvider, isNull);
    expect(cleared.hasUserPhoto, isFalse);
    expect(item.hasUserPhoto, isTrue);
  });

  test('toFirestore omits photo fields when none are set', () {
    final data = _milk().toFirestore(userId: 'uid');
    expect(data.containsKey('photoUrl'), isFalse);
    expect(data.containsKey('photoStoragePath'), isFalse);
  });

  test('toFirestore stores download URL not image bytes', () {
    final data = _milk(
      photoUrl: 'https://example.com/milk.jpg',
      photoStoragePath: 'users/uid/pantryItems/doc-milk/photo.jpg',
    ).toFirestore(userId: 'uid');

    expect(data['photoUrl'], 'https://example.com/milk.jpg');
    expect(
      data['photoStoragePath'],
      'users/uid/pantryItems/doc-milk/photo.jpg',
    );
  });
}
