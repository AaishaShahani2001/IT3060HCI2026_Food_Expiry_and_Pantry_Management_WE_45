import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';
import '../widgets/pantry_item_form.dart';

class PantryItemFormScreen extends ConsumerStatefulWidget {
  const PantryItemFormScreen({this.item, super.key});

  final PantryItem? item;

  @override
  ConsumerState<PantryItemFormScreen> createState() =>
      _PantryItemFormScreenState();
}

class _PantryItemFormScreenState extends ConsumerState<PantryItemFormScreen> {
  bool _isSaving = false;

  Future<void> _handleSubmit(PantryItemFormData data) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(pantryItemsProvider.notifier);
      if (widget.item == null) {
        await notifier.addItem(
          PantryItem(
            id: '',
            name: data.name,
            category: data.category,
            location: data.location,
            quantity: data.quantity,
            unit: data.unit,
            price: data.price,
            expiryDate: data.expiryDate,
          ),
        );
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw const PantryFirestoreException(
            'Please log in before continuing.',
          );
        }

        if (!widget.item!.isConnectedToFirestore) {
          throw const PantryFirestoreException(
            'This item is local-only and is not connected to Firestore yet.',
          );
        }

        // copyWith keeps firestoreId, createdAt, and any fields the form
        // does not collect (this model has no image or barcode).
        final updatedItem = widget.item!.copyWith(
          name: data.name,
          category: data.category,
          location: data.location,
          quantity: data.quantity,
          unit: data.unit,
          price: data.price,
          expiryDate: data.expiryDate,
          clearExpiryDate: data.expiryDate == null,
        );

        await notifier.updateItem(updatedItem);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              widget.item == null
                  ? '${data.name} added to your pantry'
                  : 'Item updated successfully.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Pantry item save failed: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.statusRed,
            content: Text(mapPantryFirestoreError(error)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Scaffold(
      appBar: AppBar(
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
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PantryItemForm(
                  initialItem: widget.item,
                  isSaving: _isSaving,
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
