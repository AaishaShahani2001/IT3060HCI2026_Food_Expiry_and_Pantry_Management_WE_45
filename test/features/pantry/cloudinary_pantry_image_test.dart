import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/cloudinary_config.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/cloudinary_image_service.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_firestore_service.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_item_photo_save.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/utils/pantry_image_url.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  const config = CloudinaryConfig(
    cloudName: 'test-cloud',
    uploadPreset: 'pantry_unsigned',
  );

  PantryItem milk({
    String? photoUrl,
    String? photoStoragePath,
    String? imagePublicId,
    String? imageProvider,
  }) {
    return PantryItem(
      id: 'milk',
      firestoreId: 'milk',
      name: 'Milk',
      category: PantryCategory.dairy,
      location: PantryLocation.refrigerator,
      quantity: 1,
      unit: PantryUnit.bottles,
      price: 450,
      photoUrl: photoUrl,
      photoStoragePath: photoStoragePath,
      imagePublicId: imagePublicId,
      imageProvider: imageProvider,
    );
  }

  XFile photoFile({
    String name = 'milk.jpg',
    String? mimeType,
    int length = 4,
  }) {
    return XFile.fromData(
      Uint8List.fromList(List<int>.filled(length, 1)),
      name: name,
      mimeType: mimeType ?? 'image/jpeg',
    );
  }

  CloudinaryImageService service(
    _ScriptedClient client, {
    CloudinaryConfig? cloudinary,
    int? maxBytes,
  }) {
    return CloudinaryImageService(
      httpClient: client,
      config: cloudinary ?? config,
      maxBytes: maxBytes ?? kPantryImageMaxBytes,
    );
  }

  test(
    'add item without a photo skips Cloudinary and keeps image fields null',
    () async {
      final client = _ScriptedClient((_) async => _jsonResponse(200, {}));
      final photos = PantryItemPhotoSave(service(client));
      PantryItem? saved;

      await photos.createItem(
        item: milk(),
        userId: 'user-1',
        save: (item) async => saved = item,
      );

      expect(client.calls, 0);
      expect(saved?.photoUrl, isNull);
      expect(saved?.imagePublicId, isNull);
      expect(saved?.imageProvider, isNull);
    },
  );

  test('add item stores a successful Cloudinary upload', () async {
    http.BaseRequest? captured;
    final client = _ScriptedClient((request) async {
      captured = request;
      return _jsonResponse(200, {
        'secure_url':
            'https://res.cloudinary.com/test-cloud/image/upload/v1/freshtrack/pantry/user-1/milk.jpg',
        'public_id': 'freshtrack/pantry/user-1/milk',
        'width': 300,
        'height': 300,
        'format': 'jpg',
      });
    });
    final photos = PantryItemPhotoSave(service(client));
    PantryItem? saved;

    await photos.createItem(
      item: milk(),
      userId: 'user-1',
      photo: photoFile(),
      save: (item) async => saved = item,
    );

    final multipart = captured! as http.MultipartRequest;
    expect(multipart.url.path, '/v1_1/test-cloud/image/upload');
    expect(multipart.fields['upload_preset'], 'pantry_unsigned');
    expect(multipart.fields['folder'], 'freshtrack/pantry/user-1');
    expect(multipart.files.single.field, 'file');
    expect(
      saved?.photoUrl,
      'https://res.cloudinary.com/test-cloud/image/upload/v1/freshtrack/pantry/user-1/milk.jpg',
    );
    expect(saved?.imagePublicId, 'freshtrack/pantry/user-1/milk');
    expect(saved?.imageProvider, 'cloudinary');
    expect(saved?.photoStoragePath, isNull);
  });

  test('Cloudinary upload failure prevents the Firestore save', () async {
    final photos = PantryItemPhotoSave(
      service(
        _ScriptedClient((_) async => _jsonResponse(500, {'error': 'no'})),
      ),
    );
    var saved = false;

    await expectLater(
      photos.createItem(
        item: milk(),
        userId: 'user-1',
        photo: photoFile(),
        save: (_) async => saved = true,
      ),
      throwsA(isA<PantryImageUploadException>()),
    );
    expect(saved, isFalse);
  });

  test('invalid file type is rejected before upload', () async {
    final client = _ScriptedClient((_) async => _jsonResponse(200, {}));
    final images = service(client);

    await expectLater(
      images.uploadPantryImage(
        userId: 'user-1',
        photo: photoFile(name: 'notes.gif', mimeType: 'image/gif'),
      ),
      throwsA(
        isA<PantryFirestoreException>().having(
          (error) => error.message,
          'message',
          kPantryImageTypeMessage,
        ),
      ),
    );
    expect(client.calls, 0);
  });

  test('oversized image is rejected before upload', () async {
    final client = _ScriptedClient((_) async => _jsonResponse(200, {}));
    final images = service(client, maxBytes: 4);

    await expectLater(
      images.uploadPantryImage(userId: 'user-1', photo: photoFile(length: 5)),
      throwsA(
        isA<PantryFirestoreException>().having(
          (error) => error.message,
          'message',
          kPantryImageTooLargeMessage,
        ),
      ),
    );
    expect(client.calls, 0);
  });

  test('missing Cloudinary configuration returns a controlled error', () async {
    final images = service(
      _ScriptedClient((_) async => _jsonResponse(200, {})),
      cloudinary: const CloudinaryConfig(cloudName: '', uploadPreset: ''),
    );

    await expectLater(
      images.uploadPantryImage(userId: 'user-1', photo: photoFile()),
      throwsA(isA<PantryImageConfigurationException>()),
    );
  });

  test('edit without an image change does not upload again', () async {
    final client = _ScriptedClient((_) async => _jsonResponse(200, {}));
    final existing = milk(
      photoUrl:
          'https://res.cloudinary.com/test-cloud/image/upload/v1/milk.jpg',
      imagePublicId: 'freshtrack/pantry/user-1/milk',
      imageProvider: 'cloudinary',
    );

    final updated = await PantryItemPhotoSave(service(client)).prepareEdit(
      item: existing.copyWith(name: 'Whole milk'),
      userId: 'user-1',
      removeExistingPhoto: false,
    );

    expect(client.calls, 0);
    expect(updated.name, 'Whole milk');
    expect(updated.photoUrl, existing.photoUrl);
    expect(updated.imagePublicId, existing.imagePublicId);
    expect(updated.imageProvider, 'cloudinary');
  });

  test('edit can add a Cloudinary photo', () async {
    final updated =
        await PantryItemPhotoSave(
          service(
            _ScriptedClient(
              (_) async => _jsonResponse(200, {
                'secure_url':
                    'https://res.cloudinary.com/test-cloud/image/upload/v1/new.jpg',
                'public_id': 'freshtrack/pantry/user-1/new',
              }),
            ),
          ),
        ).prepareEdit(
          item: milk(),
          userId: 'user-1',
          selectedPhoto: photoFile(),
          removeExistingPhoto: false,
        );

    expect(
      updated.photoUrl,
      'https://res.cloudinary.com/test-cloud/image/upload/v1/new.jpg',
    );
    expect(updated.imagePublicId, 'freshtrack/pantry/user-1/new');
    expect(updated.imageProvider, 'cloudinary');
  });

  test('edit replaces a photo only after the new upload succeeds', () async {
    final existing = milk(
      photoUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/milk.jpg',
      photoStoragePath: 'users/user-1/pantryItems/milk/photo.jpg',
    );
    final photos = PantryItemPhotoSave(
      service(_ScriptedClient((_) async => _jsonResponse(500, {}))),
    );

    await expectLater(
      photos.prepareEdit(
        item: existing,
        userId: 'user-1',
        selectedPhoto: photoFile(),
        removeExistingPhoto: false,
      ),
      throwsA(isA<PantryImageUploadException>()),
    );

    final replaced =
        await PantryItemPhotoSave(
          service(
            _ScriptedClient(
              (_) async => _jsonResponse(200, {
                'secure_url':
                    'https://res.cloudinary.com/test-cloud/image/upload/v1/next.jpg',
                'public_id': 'freshtrack/pantry/user-1/next',
                'format': 'jpg',
              }),
            ),
          ),
        ).prepareEdit(
          item: existing,
          userId: 'user-1',
          selectedPhoto: photoFile(),
          removeExistingPhoto: false,
        );

    expect(existing.photoUrl, contains('firebasestorage.googleapis.com'));
    expect(replaced.photoUrl, contains('res.cloudinary.com'));
    expect(replaced.imagePublicId, 'freshtrack/pantry/user-1/next');
    expect(replaced.photoStoragePath, isNull);
  });

  test('edit removes the photo reference without uploading', () async {
    final client = _ScriptedClient((_) async => _jsonResponse(200, {}));
    final updated = await PantryItemPhotoSave(service(client)).prepareEdit(
      item: milk(
        photoUrl:
            'https://res.cloudinary.com/test-cloud/image/upload/v1/milk.jpg',
        imagePublicId: 'freshtrack/pantry/user-1/milk',
        imageProvider: 'cloudinary',
      ),
      userId: 'user-1',
      removeExistingPhoto: true,
    );

    expect(client.calls, 0);
    expect(updated.photoUrl, isNull);
    expect(updated.imagePublicId, isNull);
    expect(updated.imageProvider, isNull);
    expect(updated.hasUserPhoto, isFalse);
  });

  test('a response without secure_url or public_id is rejected', () async {
    final images = service(
      _ScriptedClient(
        (_) async => _jsonResponse(200, {
          'secure_url': 'https://res.cloudinary.com/x/a.jpg',
        }),
      ),
    );

    await expectLater(
      images.uploadPantryImage(userId: 'user-1', photo: photoFile()),
      throwsA(isA<PantryImageUploadException>()),
    );

    final missingUrl = service(
      _ScriptedClient(
        (_) async =>
            _jsonResponse(200, {'public_id': 'freshtrack/pantry/user-1/milk'}),
      ),
    );
    await expectLater(
      missingUrl.uploadPantryImage(userId: 'user-1', photo: photoFile()),
      throwsA(isA<PantryImageUploadException>()),
    );
  });

  test('Firestore failure after upload is not treated as a saved item', () async {
    final photos = PantryItemPhotoSave(
      service(
        _ScriptedClient(
          (_) async => _jsonResponse(200, {
            'secure_url':
                'https://res.cloudinary.com/test-cloud/image/upload/v1/milk.jpg',
            'public_id': 'freshtrack/pantry/user-1/milk',
          }),
        ),
      ),
    );

    await expectLater(
      photos.createItem(
        item: milk(),
        userId: 'user-1',
        photo: photoFile(),
        save: (_) async => throw const PantryFirestoreException(
          'Something went wrong. Please try again.',
        ),
      ),
      throwsA(isA<PantryFirestoreException>()),
    );
  });

  test('legacy Firebase URLs are not rewritten as Cloudinary transforms', () {
    const firebaseUrl =
        'https://firebasestorage.googleapis.com/v0/b/app/o/milk.jpg?alt=media';
    expect(
      pantryDisplayImageUrl(firebaseUrl, delivery: PantryImageDelivery.card),
      firebaseUrl,
    );

    final cloudinary = pantryDisplayImageUrl(
      'https://res.cloudinary.com/test-cloud/image/upload/v1/freshtrack/pantry/user-1/milk.jpg',
      delivery: PantryImageDelivery.card,
    );
    expect(cloudinary, contains('/upload/f_auto,q_auto,w_300,h_300,c_fill/'));

    final details = pantryDisplayImageUrl(
      'https://res.cloudinary.com/test-cloud/image/upload/v1/freshtrack/pantry/user-1/milk.jpg',
      delivery: PantryImageDelivery.details,
    );
    expect(details, contains('/upload/f_auto,q_auto,w_900,c_limit/'));
  });

  test('client source does not contain a Cloudinary API secret', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    const forbidden = [
      'CLOUDINARY_API_SECRET',
      'CLOUDINARY_API_KEY',
      'api_secret',
    ];

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final token in forbidden) {
        expect(
          source.contains(token),
          isFalse,
          reason: '${file.path} contains $token',
        );
      }
    }
  });
}

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls++;
    return _handler(request);
  }
}

http.StreamedResponse _jsonResponse(int status, Object body) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
    status,
  );
}
