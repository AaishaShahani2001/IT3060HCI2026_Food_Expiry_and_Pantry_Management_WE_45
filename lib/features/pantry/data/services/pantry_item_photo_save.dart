import 'package:image_picker/image_picker.dart';

import '../../domain/models/pantry_item.dart';
import 'cloudinary_config.dart';
import 'cloudinary_image_service.dart';

/// Applies an optional Cloudinary photo while a pantry item is saved.
///
/// Upload runs before the Firestore write. A failed upload never calls [save],
/// so a local file path is never stored. If Cloudinary succeeds and Firestore
/// then fails, the uploaded file can be left without a document. Unsigned
/// client code cannot delete it; a future backend may clean up [imagePublicId].
class PantryItemPhotoSave {
  const PantryItemPhotoSave(this._images);

  final CloudinaryImageService _images;

  Future<void> createItem({
    required PantryItem item,
    required String userId,
    XFile? photo,
    required Future<void> Function(PantryItem item) save,
    Future<PantryImageUploadResult?> Function(XFile photo)? upload,
  }) async {
    final prepared = await prepareCreate(
      item: item,
      userId: userId,
      photo: photo,
      upload: upload,
    );
    try {
      await save(prepared);
    } catch (_) {
      // prepared.imagePublicId may now point at an unused Cloudinary file.
      // Do not report the pantry item as saved, and do not call Cloudinary
      // admin APIs from this client.
      rethrow;
    }
  }

  Future<PantryItem> prepareCreate({
    required PantryItem item,
    required String userId,
    XFile? photo,
    Future<PantryImageUploadResult?> Function(XFile photo)? upload,
  }) async {
    if (photo == null) return item;
    final uploaded = upload != null
        ? await upload(photo)
        : await _images.uploadPantryImage(userId: userId, photo: photo);
    if (uploaded == null) return item;
    return applyCloudinaryPhoto(item, uploaded);
  }

  Future<PantryItem> prepareEdit({
    required PantryItem item,
    required String userId,
    XFile? selectedPhoto,
    required bool removeExistingPhoto,
    Future<PantryImageUploadResult?> Function(XFile photo)? upload,
  }) async {
    if (selectedPhoto != null) {
      final uploaded = upload != null
          ? await upload(selectedPhoto)
          : await _images.uploadPantryImage(
              userId: userId,
              photo: selectedPhoto,
            );
      if (uploaded == null) return item;
      return applyCloudinaryPhoto(item, uploaded);
    }

    if (removeExistingPhoto) {
      // Remove the Firestore photo reference only. Destroying the Cloudinary
      // asset needs a signed backend request, which this client does not have.
      return item.copyWith(clearPhoto: true);
    }

    return item;
  }
}

PantryItem applyCloudinaryPhoto(
  PantryItem item,
  PantryImageUploadResult result,
) {
  return item.copyWith(
    photoUrl: result.secureUrl,
    imagePublicId: result.publicId,
    imageProvider: kCloudinaryImageProvider,
    clearPhotoStoragePath: true,
  );
}
