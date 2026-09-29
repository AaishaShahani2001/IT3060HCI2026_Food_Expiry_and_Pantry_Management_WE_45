import 'package:flutter/material.dart';

/// Shared Pantry SnackBars. Always hides the current one first, so rapid
/// actions such as repeated +/- taps replace the message instead of stacking.
abstract final class PantrySnackBar {
  /// Undo windows: long enough to reach for, short enough that the floating
  /// SnackBar does not hover over the list behind it.
  static const Duration usedUpUndo = Duration(seconds: 4);
  static const Duration quantityUndo = Duration(seconds: 3);
  static const Duration markConsumedUndo = Duration(seconds: 3);

  /// Success and error text with nothing to act on.
  static const Duration standard = Duration(seconds: 3);

  /// Short confirmation shown once an Undo has been written.
  static const Duration confirmation = Duration(seconds: 2);

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = standard,
    SnackBarAction? action,
    bool isError = false,
  }) {
    if (!context.mounted) return;
    showOn(
      ScaffoldMessenger.of(context),
      message: message,
      duration: duration,
      action: action,
      isError: isError,
    );
  }

  static void showOn(
    ScaffoldMessengerState messenger, {
    required String message,
    Duration duration = standard,
    SnackBarAction? action,
    bool isError = false,
  }) {
    if (!messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          backgroundColor: isError
              ? Theme.of(messenger.context).colorScheme.error
              : null,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
