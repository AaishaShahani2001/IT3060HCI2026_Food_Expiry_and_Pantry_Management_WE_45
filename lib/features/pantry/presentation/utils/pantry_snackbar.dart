import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Shared Pantry SnackBars. Always hides the current one first, so rapid
/// actions such as repeated +/- taps replace the message instead of stacking.
abstract final class PantrySnackBar {
  /// Used Up feedback. A SnackBar action defaults to [SnackBar.persist], so
  /// this message puts both actions in the content and sets [SnackBar.persist]
  /// to false. The framework timer then dismisses it after three seconds.
  static const Duration usedUpUndo = Duration(seconds: 3);
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

  /// Used Up feedback with Undo and Add to List.
  ///
  /// Clears any current Pantry SnackBar first. [SnackBar.persist] is false, so
  /// the bar leaves on its own after [usedUpUndo] even though it has actions.
  /// Either action hides this bar immediately. A later timeout cannot run the
  /// action again.
  static void showUsedUp(
    ScaffoldMessengerState messenger, {
    required String itemName,
    required VoidCallback onUndo,
    required VoidCallback onAddToList,
  }) {
    if (!messenger.mounted) return;
    messenger.clearSnackBars();
    var settled = false;

    void finish(VoidCallback action) {
      if (settled || !messenger.mounted) return;
      settled = true;
      messenger.hideCurrentSnackBar();
      action();
    }

    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: usedUpUndo,
        persist: false,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: PantryUsedUpSnackBarContent(
          itemName: itemName,
          onUndo: () => finish(onUndo),
          onAddToList: () => finish(onAddToList),
        ),
      ),
    );
    unawaited(
      controller.closed.then((reason) {
        if (reason == SnackBarClosedReason.timeout ||
            reason == SnackBarClosedReason.swipe ||
            reason == SnackBarClosedReason.dismiss ||
            reason == SnackBarClosedReason.remove) {
          settled = true;
        }
      }),
    );
  }
}

/// Two compact actions inside the Used Up SnackBar.
///
/// The standard [SnackBar.action] slot only fits one button, and providing it
/// makes the bar persist. These actions stay inside the bar so it can still
/// time out.
class PantryUsedUpSnackBarContent extends StatelessWidget {
  const PantryUsedUpSnackBarContent({
    required this.itemName,
    required this.onUndo,
    required this.onAddToList,
    super.key,
  });

  final String itemName;
  final VoidCallback onUndo;
  final VoidCallback onAddToList;

  static const Key undoKey = Key('pantry-used-up-undo');
  static const Key addToListKey = Key('pantry-used-up-add-to-list');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = '$itemName marked as used up.';
    final background =
        theme.snackBarTheme.backgroundColor ?? theme.colorScheme.inverseSurface;
    final messageColor =
        theme.snackBarTheme.contentTextStyle?.color ??
        theme.colorScheme.onInverseSurface;
    final addColor = background.computeLuminance() > 0.45
        ? AppColors.darkGreen
        : AppColors.primaryGreen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: TextStyle(color: messageColor, height: 1.3)),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 0,
              children: [
                _UsedUpSnackAction(
                  key: undoKey,
                  maxWidth: constraints.maxWidth,
                  label: 'UNDO',
                  tooltip: 'Undo',
                  semanticLabel: 'Undo',
                  icon: Icons.undo,
                  color: messageColor,
                  onPressed: onUndo,
                ),
                _UsedUpSnackAction(
                  key: addToListKey,
                  maxWidth: constraints.maxWidth,
                  label: 'ADD TO LIST',
                  tooltip: 'Add $itemName to Shopping List',
                  semanticLabel: 'Add $itemName to Shopping List',
                  icon: Icons.add_shopping_cart_outlined,
                  color: addColor,
                  onPressed: onAddToList,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UsedUpSnackAction extends StatelessWidget {
  const _UsedUpSnackAction({
    required this.maxWidth,
    required this.label,
    required this.tooltip,
    required this.semanticLabel,
    required this.icon,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final double maxWidth;
  final String label;
  final String tooltip;
  final String semanticLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: tooltip,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 48, maxWidth: maxWidth),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: color,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onPressed,
            child: ExcludeSemantics(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  Icon(icon, size: 18, color: color),
                  Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
