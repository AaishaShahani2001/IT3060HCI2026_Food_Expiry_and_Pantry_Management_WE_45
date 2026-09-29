import 'package:flutter/material.dart';

/// Shown when a pantry photo upload fails. Returns null if dismissed.
enum PantryPhotoUploadFailureAction { tryAgain, saveWithoutPhoto, cancel }

Future<PantryPhotoUploadFailureAction?> showPhotoUploadFailureDialog(
  BuildContext context,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return showDialog<PantryPhotoUploadFailureAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'We couldn’t upload the photo.',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Your item details are still here. Try again, save without a photo, or cancel.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(PantryPhotoUploadFailureAction.cancel),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(PantryPhotoUploadFailureAction.saveWithoutPhoto),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Save Without Photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(PantryPhotoUploadFailureAction.tryAgain),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      );
    },
  );
}
