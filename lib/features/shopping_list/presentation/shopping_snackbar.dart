import 'package:flutter/material.dart';

abstract final class ShoppingSnackBar {
  static const Duration standard = Duration(seconds: 2);
  static const Duration action = Duration(seconds: 3);
  static const Duration error = Duration(seconds: 8);

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = standard,
    SnackBarAction? snackBarAction,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: snackBarAction == null
            ? Text(message)
            : Row(
                children: [
                  Expanded(child: Text(message)),
                  TextButton(
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      snackBarAction.onPressed();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.inversePrimary,
                    ),
                    child: Text(snackBarAction.label),
                  ),
                ],
              ),
        duration: duration,
      ),
    );
  }
}
