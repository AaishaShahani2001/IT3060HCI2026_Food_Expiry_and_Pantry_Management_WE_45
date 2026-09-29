import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/pantry_firestore_service.dart';
import '../../data/services/pantry_photo_storage_service.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';
import '../utils/pantry_snackbar.dart';
import '../widgets/duplicate_item_dialog.dart';
import '../widgets/pantry_item_form.dart';
import '../widgets/pantry_photo_upload_failure_dialog.dart';

class PantryItemFormScreen extends ConsumerStatefulWidget {
  const PantryItemFormScreen({this.item, super.key});

  final PantryItem? item;

  @override
  ConsumerState<PantryItemFormScreen> createState() =>
      _PantryItemFormScreenState();
}

class _PantryItemFormScreenState extends ConsumerState<PantryItemFormScreen> {
  bool _isSaving = false;
  String? _savingMessage;

  Future<void> _handleSubmit(PantryItemFormData data) async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _savingMessage = data.selectedPhoto != null
          ? 'Uploading photo and saving item…'
          : 'Saving item…';
    });

    try {
      final duplicate = ref
          .read(pantryItemsProvider.notifier)
          .findDuplicateByName(data.name, excludeItemId: widget.item?.id);

      if (duplicate != null) {
        if (!mounted) return;

        final action = await showDuplicateItemDialog(
          context: context,
          existingItem: duplicate,
        );

        if (!mounted) return;

        if (action == DuplicateItemAction.updateExisting) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PantryItemFormScreen(item: duplicate),
            ),
          );
          return;
        }

        if (action != DuplicateItemAction.addAnyway) {
          return;
        }
      }

      final saved = await _persistItem(data);
      if (!saved || !mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      PantrySnackBar.showOn(
        messenger,
        message: widget.item == null
            ? '${data.name} added to your pantry'
            : 'Item updated successfully.',
      );
    } on _PhotoSaveCancelled {
      return;
    } catch (error, stackTrace) {
      debugPrint('Pantry item save failed: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        PantrySnackBar.error(context, mapPantryFirestoreError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingMessage = null;
        });
      }
    }
  }

  Future<bool> _persistItem(PantryItemFormData data) async {
    final notifier = ref.read(pantryItemsProvider.notifier);
    if (widget.item == null) {
      return _addItem(notifier, data);
    }
    return _updateItem(notifier, data);
  }

  Future<bool> _addItem(
    PantryItemsNotifier notifier,
    PantryItemFormData data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PantryFirestoreException('Please log in before continuing.');
    }

    // Generate the document ID first so Storage and Firestore share it.
    final itemId = notifier.generateNewItemId(user.uid);
    PantryPhotoUpload? photo;
    if (data.selectedPhoto != null) {
      photo = await _uploadWithRecovery(
        notifier: notifier,
        userId: user.uid,
        itemId: itemId,
        photo: data.selectedPhoto!,
      );
      if (photo == null && !mounted) return false;
    }

    try {
      await notifier.addItem(
        PantryItem(
          id: itemId,
          firestoreId: itemId,
          name: data.name,
          category: data.category,
          location: data.location,
          quantity: data.quantity,
          unit: data.unit,
          price: data.price,
          expiryDate: data.expiryDate,
          photoUrl: photo?.downloadUrl,
          photoStoragePath: photo?.storagePath,
        ),
      );
      return true;
    } catch (error) {
      if (photo != null) {
        await notifier.deleteItemPhoto(storagePath: photo.storagePath);
      }
      rethrow;
    }
  }

  Future<bool> _updateItem(
    PantryItemsNotifier notifier,
    PantryItemFormData data,
  ) async {
    final existing = widget.item!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PantryFirestoreException('Please log in before continuing.');
    }

    if (!existing.isConnectedToFirestore) {
      throw const PantryFirestoreException(
        'This item is local-only and is not connected to Firestore yet.',
      );
    }

    final itemId = existing.firestoreId!;
    final previousPath = existing.photoStoragePath;
    PantryPhotoUpload? replacement;
    var clearPhoto = data.removeExistingPhoto && data.selectedPhoto == null;

    if (data.selectedPhoto != null) {
      replacement = await _uploadWithRecovery(
        notifier: notifier,
        userId: user.uid,
        itemId: itemId,
        photo: data.selectedPhoto!,
      );
      if (replacement == null) {
        clearPhoto = false;
      }
    }

    final updatedItem = existing.copyWith(
      name: data.name,
      category: data.category,
      location: data.location,
      quantity: data.quantity,
      unit: data.unit,
      price: data.price,
      expiryDate: data.expiryDate,
      clearExpiryDate: data.expiryDate == null,
      photoUrl: replacement?.downloadUrl,
      photoStoragePath: replacement?.storagePath,
      clearPhoto: clearPhoto,
    );

    await notifier.updateItem(updatedItem);

    if (clearPhoto && previousPath != null && previousPath.trim().isNotEmpty) {
      await notifier.deleteItemPhoto(storagePath: previousPath);
    } else if (replacement != null &&
        previousPath != null &&
        previousPath.trim().isNotEmpty &&
        previousPath != replacement.storagePath) {
      // Keep the previous Storage object until the replacement URL is saved.
      await notifier.deleteItemPhoto(storagePath: previousPath);
    }

    return true;
  }

  /// Returns the upload result, or null when the user chose Save Without Photo.
  Future<PantryPhotoUpload?> _uploadWithRecovery({
    required PantryItemsNotifier notifier,
    required String userId,
    required String itemId,
    required XFile photo,
  }) async {
    while (mounted) {
      try {
        setState(() {
          _savingMessage = 'Uploading photo and saving item…';
        });
        return await notifier.uploadItemPhoto(
          userId: userId,
          itemId: itemId,
          photo: photo,
        );
      } catch (error, stackTrace) {
        debugPrint('Pantry photo upload failed: $error');
        debugPrint('$stackTrace');
        if (!mounted) throw const _PhotoSaveCancelled();
        setState(() => _savingMessage = null);
        final action = await showPhotoUploadFailureDialog(context);
        if (!mounted ||
            action == null ||
            action == PantryPhotoUploadFailureAction.cancel) {
          throw const _PhotoSaveCancelled();
        }
        if (action == PantryPhotoUploadFailureAction.saveWithoutPhoto) {
          setState(() => _savingMessage = 'Saving item…');
          return null;
        }
      }
    }
    throw const _PhotoSaveCancelled();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surface,
        title: Text(isEditing ? 'Edit Item' : 'Add Item'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.24
                            : 0.03,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PantryItemForm(
                  initialItem: widget.item,
                  isSaving: _isSaving,
                  savingMessage: _savingMessage,
                  onSubmit: _handleSubmit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoSaveCancelled implements Exception {
  const _PhotoSaveCancelled();
}
