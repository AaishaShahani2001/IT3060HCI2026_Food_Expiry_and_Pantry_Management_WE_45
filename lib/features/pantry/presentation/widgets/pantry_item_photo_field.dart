import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/pantry_item.dart';

/// Optional pantry item photo picker used by Add/Edit Item.
class PantryItemPhotoField extends StatelessWidget {
  const PantryItemPhotoField({
    required this.category,
    required this.hasPreview,
    required this.enabled,
    required this.onAddPhoto,
    required this.onChangePhoto,
    required this.onRemovePhoto,
    this.preview,
    super.key,
  });

  final PantryCategory category;

  final bool hasPreview;
  final bool enabled;
  final Widget? preview;
  final VoidCallback onAddPhoto;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Item Photo (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add a photo to recognize this item more easily.',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (hasPreview && preview != null)
          _SelectedPreview(
            enabled: enabled,
            preview: preview!,
            onChange: onChangePhoto,
            onRemove: onRemovePhoto,
          )
        else
          _EmptyPlaceholder(
            enabled: enabled,
            category: category,
            onAdd: onAddPhoto,
          ),
      ],
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({
    required this.enabled,
    required this.category,
    required this.onAdd,
  });

  final bool enabled;
  final PantryCategory category;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 36, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                'Optional',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Tooltip(
          message: 'Add an optional item photo',
          child: OutlinedButton.icon(
            onPressed: enabled ? onAdd : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add Photo'),
          ),
        ),
      ],
    );
  }
}

class _SelectedPreview extends StatelessWidget {
  const _SelectedPreview({
    required this.enabled,
    required this.preview,
    required this.onChange,
    required this.onRemove,
  });

  final bool enabled;
  final Widget preview;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Semantics(
          image: true,
          label: 'Selected item photo',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: preview,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: enabled ? onChange : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Change Photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: enabled ? onRemove : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Remove Photo'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<ImageSource?> showPantryPhotoSourceSheet(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: colorScheme.surfaceContainerHighest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
                minVerticalPadding: 16,
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                minVerticalPadding: 16,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
