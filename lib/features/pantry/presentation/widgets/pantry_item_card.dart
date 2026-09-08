import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';
import 'expiry_status_indicator.dart';

class PantryItemCard extends StatelessWidget {
  const PantryItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
    super.key,
  });

  final PantryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final canDecrement = item.quantity > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: image, info, actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.category.icon,
                        size: 24,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: ExpiryStatusIndicator(status: item.expiryStatus),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.heading,
                              ),
                            ),
                          ),
                          if (item.isLowStock) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusAmberBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Low',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.statusAmber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.category.label} · ${item.location.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Edit ${item.name}',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: AppColors.primaryDark,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'Delete ${item.name}',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppColors.statusRed,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Bottom section: quantity label + unified stepper
            Row(
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 148,
                        maxWidth: 196,
                      ),
                      child: SizedBox(
                        width: 180,
                        child: _QuantityStepper(
                          quantityLabel: item.quantityLabel,
                          canDecrement: canDecrement,
                          onIncrement: onIncrement,
                          onDecrement: onDecrement,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantityLabel,
    required this.canDecrement,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String quantityLabel;
  final bool canDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.softGreen.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            tooltip: 'Decrease quantity',
            enabled: canDecrement,
            foreground: AppColors.badgeTextDark,
            onPressed: onDecrement,
          ),
          Container(
            width: 1,
            height: double.infinity,
            color: AppColors.cardBorder,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    quantityLabel,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: double.infinity,
            color: AppColors.cardBorder,
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: 'Increase quantity',
            enabled: true,
            foreground: AppColors.primaryDark,
            onPressed: onIncrement,
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
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          splashColor: AppColors.primaryGreen.withValues(alpha: 0.15),
          highlightColor: AppColors.primaryGreen.withValues(alpha: 0.06),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? foreground
                  : AppColors.textSecondary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
