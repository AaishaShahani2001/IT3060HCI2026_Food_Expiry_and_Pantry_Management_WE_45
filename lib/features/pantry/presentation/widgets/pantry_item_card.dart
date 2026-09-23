import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';
import 'expiry_status_indicator.dart';
import 'pantry_item_actions_sheet.dart';
import 'pantry_quantity_stepper.dart';

/// Image-focused 2-column grid card for All Pantry Items card view.
class PantryItemCard extends StatelessWidget {
  const PantryItemCard({
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
    final imageBg = isDark
        ? FreshPalette.darkAccentSurface
        : colorScheme.secondaryContainer.withValues(alpha: 0.6);
    final primaryText = isDark ? FreshPalette.darkHeading : FreshPalette.heading;
    final secondaryText = isDark
        ? FreshPalette.darkSecondaryText
        : FreshPalette.secondaryText;

    final status = item.expiryStatus;
    final statusColor = status.colorFor(colorScheme);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prominent Top Image/Icon Hero Section
            Stack(
              children: [
                Container(
                  height: 92,
                  width: double.infinity,
                  color: imageBg,
                  child: Center(
                    child: Icon(
                      item.category.icon,
                      size: 42,
                      color: isDark
                          ? FreshPalette.highlight
                          : FreshPalette.primaryButton,
                    ),
                  ),
                ),
                // Expiry status indicator dot (top right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: ExpiryStatusIndicator(
                    status: status,
                    size: 13,
                  ),
                ),
                // Stock status badge (top left)
                if (item.isOutOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.statusRed.withValues(alpha: 0.3)
                            : AppColors.statusRedBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.statusRed.withValues(alpha: 0.4),
                        ),
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
                  )
                else if (item.isLowStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.statusAmber.withValues(alpha: 0.3)
                            : AppColors.statusAmberBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.statusAmber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'Low stock',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusAmber,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Card Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Name & Action Menu Row
                    Row(
                      children: [
                        Expanded(
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
                    const SizedBox(height: 2),
                    // Category • Location
                    Text(
                      '${item.category.label} • ${item.location.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Quantity & Expiry indicator row
                    Row(
                      children: [
                        Icon(status.icon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            status.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Bottom Quantity Stepper
                    PantryQuantityStepper(
                      quantityLabel: item.quantityLabel,
                      canDecrement: canDecrement,
                      isUpdating: isUpdating,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

