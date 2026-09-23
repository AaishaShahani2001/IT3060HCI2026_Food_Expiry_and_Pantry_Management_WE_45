import 'package:flutter/material.dart';

/// Shared +/- quantity control used by card and list item layouts.
class PantryQuantityStepper extends StatelessWidget {
  const PantryQuantityStepper({
    required this.quantityLabel,
    required this.canDecrement,
    required this.isUpdating,
    required this.onIncrement,
    required this.onDecrement,
    this.height = 42,
    super.key,
  });

  final String quantityLabel;
  final bool canDecrement;
  final bool isUpdating;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            tooltip: 'Decrease quantity',
            enabled: canDecrement,
            foreground: colorScheme.onSurface,
            onPressed: onDecrement,
            height: height,
          ),
          Container(
            width: 1,
            height: double.infinity,
            color: colorScheme.outline,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: isUpdating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          quantityLabel,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: double.infinity,
            color: colorScheme.outline,
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: 'Increase quantity',
            enabled: !isUpdating,
            foreground: colorScheme.primary,
            onPressed: onIncrement,
            height: height,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.foreground,
    required this.onPressed,
    this.height = 42,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color foreground;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          splashColor: colorScheme.primary.withValues(alpha: 0.15),
          highlightColor: colorScheme.primary.withValues(alpha: 0.06),
          child: SizedBox(
            width: height,
            height: height,
            child: Icon(
              icon,
              size: 16,
              color: enabled
                  ? foreground
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
