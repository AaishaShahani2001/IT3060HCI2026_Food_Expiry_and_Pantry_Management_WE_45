import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'pantry_firestore_service.dart';

/// Result of uploading a pantry item photo to Firebase Storage.
class PantryPhotoUpload {
  const PantryPhotoUpload({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

/// User-owned pantry item photos.
///
/// Path: users/{uid}/pantryItems/{itemId}/photo.jpg
class PantryPhotoStorageService {
  PantryPhotoStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const int maxBytes = 5 * 1024 * 1024;

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  static String storagePathFor({
    required String userId,
    required String itemId,
  }) {
    return 'users/$userId/pantryItems/$itemId/photo.jpg';
  }

  /// Uploads [photo] after validation. Callers must generate [itemId] first
  /// so Firestore and Storage share the same document ID.
  Future<PantryPhotoUpload> uploadItemPhoto({
    required String userId,
    required String itemId,
    required XFile photo,
  }) async {
    _assertSupportedPhoto(photo);

    final bytes = await photo.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const PantryFirestoreException(
        'This photo is too large. Choose an image under 5 MB.',
      );
    }

    final storagePath = storagePathFor(userId: userId, itemId: itemId);
    final contentType = _contentTypeFor(photo);

    try {
      final ref = _storage.ref(storagePath);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      final downloadUrl = await ref.getDownloadURL();
      return PantryPhotoUpload(
        downloadUrl: downloadUrl,
        storagePath: storagePath,
      );
    } on FirebaseException catch (error) {
      debugPrint('Pantry photo upload failed: ${error.code} ${error.message}');
      throw const PantryFirestoreException('We couldn’t upload the photo.');
    } catch (error, stackTrace) {
      debugPrint('Pantry photo upload failed: $error');
      debugPrint('$stackTrace');
      throw const PantryFirestoreException('We couldn’t upload the photo.');
    }
  }

  /// Deletes a Storage object. Missing objects are ignored so Delete/edit
  /// cleanup does not fail the rest of the operation.
  Future<void> deleteItemPhoto({required String storagePath}) async {
    final path = storagePath.trim();
    if (path.isEmpty) return;

    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return;
      debugPrint('Pantry photo delete failed: ${error.code} ${error.message}');
    } catch (error) {
      debugPrint('Pantry photo delete failed: $error');
    }
  }

  void _assertSupportedPhoto(XFile photo) {
    final mime = photo.mimeType?.toLowerCase() ?? '';
    if (mime.isNotEmpty && !mime.startsWith('image/')) {
      throw const PantryFirestoreException(
        'Please choose a JPEG, PNG, or WebP image.',
      );
    }

    final name = photo.name.toLowerCase();
    final path = photo.path.toLowerCase();
    final extension = _extensionOf(name.isNotEmpty ? name : path);
    if (extension != null && !_allowedExtensions.contains(extension)) {
      throw const PantryFirestoreException(
        'Please choose a JPEG, PNG, or WebP image.',
      );
    }
  }

  String _contentTypeFor(XFile photo) {
    final mime = photo.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    switch (_extensionOf(photo.name) ?? _extensionOf(photo.path)) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String? _extensionOf(String value) {
    final dot = value.lastIndexOf('.');
    if (dot < 0 || dot == value.length - 1) return null;
    return value.substring(dot + 1).toLowerCase();
  }
}
