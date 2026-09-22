import 'package:flutter/material.dart';

/// Shared Pantry SnackBars. Always hides the current one first.
abstract final class PantrySnackBar {
  static const Duration undoVisibleFor = Duration(seconds: 6);

  static void show(
    BuildContext context, {
    required String message,
    SnackBarAction? action,
    bool isError = false,
  }) {
    if (!context.mounted) return;
    showOn(
      ScaffoldMessenger.of(context),
      message: message,
      action: action,
      isError: isError,
    );
  }

  static void showOn(
    ScaffoldMessengerState messenger, {
    required String message,
    SnackBarAction? action,
    bool isError = false,
  }) {
    if (!messenger.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: action != null ? undoVisibleFor : const Duration(seconds: 4),
        backgroundColor: isError
            ? Theme.of(messenger.context).colorScheme.error
            : null,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Semantics(
          liveRegion: true,
          container: true,
          label: message,
          child: Text(message),
        ),
        action: action,
      ),
    );
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, isError: true);
  }

  static void errorOn(ScaffoldMessengerState messenger, String message) {
    showOn(messenger, message: message, isError: true);
  }
}
