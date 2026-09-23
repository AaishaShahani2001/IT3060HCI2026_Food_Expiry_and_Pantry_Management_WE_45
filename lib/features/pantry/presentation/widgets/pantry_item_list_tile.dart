import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';
import 'expiry_status_indicator.dart';
import 'pantry_item_actions_sheet.dart';
import 'pantry_quantity_stepper.dart';

/// Compact horizontal tile for All Pantry Items list view.
class PantryItemListTile extends StatelessWidget {
  const PantryItemListTile({
    required this.item,
    required this.onEdit,
    required this.onUsedUp,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
    this.onTap,
    this.isUpdating = false,
    super.key,
  });

  final PantryItem item;
  final VoidCallback onEdit;
  final VoidCallback onUsedUp;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onTap;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canDecrement = !isUpdating;

    final cardBg = isDark ? FreshPalette.darkCard : FreshPalette.card;
    final borderColor = isDark ? FreshPalette.darkOutline : FreshPalette.outline;
    final thumbnailBg = isDark
        ? FreshPalette.darkAccentSurface
        : colorScheme.secondaryContainer.withValues(alpha: 0.65);
    final primaryText = isDark ? FreshPalette.darkHeading : FreshPalette.heading;
    final secondaryText = isDark
        ? FreshPalette.darkSecondaryText
        : FreshPalette.secondaryText;

    final status = item.expiryStatus;
    final statusColor = status.colorFor(colorScheme);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: Small item thumbnail with category icon & status dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: thumbnailBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.category.icon,
                        size: 24,
                        color: isDark
                            ? FreshPalette.highlight
                            : FreshPalette.primaryButton,
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: ExpiryStatusIndicator(
                        status: status,
                        size: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),

                // CENTER: Name, Category • Location, Expiry status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                          ),
                          if (item.isOutOfStock) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.statusRed.withValues(alpha: 0.25)
                                    : AppColors.statusRedBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Out of stock',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.statusRed,
                                ),
                              ),
                            ),
                          ] else if (item.isLowStock) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.statusAmber.withValues(alpha: 0.25)
                                    : AppColors.statusAmberBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Low',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.statusAmber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category.label} • ${item.location.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(status.icon, size: 11, color: statusColor),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // RIGHT: Stepper & Action menu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Qty: ${item.quantityValueLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(width: 2),
                        if (isUpdating)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              tooltip: 'Actions for ${item.name}',
                              onPressed: () async {
                                final action =
                                    await showPantryItemActionsSheet(
                                  context: context,
                                  item: item,
                                );
                                if (action == null) return;
                                switch (action) {
                                  case PantryItemSheetAction.edit:
                                    onEdit();
                                  case PantryItemSheetAction.usedUp:
                                    onUsedUp();
                                  case PantryItemSheetAction.delete:
                                    onDelete();
                                }
                              },
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: secondaryText,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 116,
                      child: PantryQuantityStepper(
                        quantityLabel: item.quantityLabel,
                        canDecrement: canDecrement,
                        isUpdating: isUpdating,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                        height: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

