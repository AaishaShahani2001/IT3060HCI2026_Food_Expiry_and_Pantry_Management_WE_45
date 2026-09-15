import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';
import 'expiry_status_indicator.dart';
import 'pantry_item_actions_sheet.dart';
import 'pantry_quantity_stepper.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.03),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'View details for ${item.name}',
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item.category.icon,
                                      size: 24,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: ExpiryStatusIndicator(
                                      status: item.expiryStatus,
                                    ),
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
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (item.isOutOfStock) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? AppColors.statusRed
                                                        .withValues(alpha: 0.2)
                                                  : AppColors.statusRedBg,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Out of stock',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.statusRed,
                                              ),
                                            ),
                                          ),
                                        ] else if (item.isLowStock) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? AppColors.statusAmber
                                                        .withValues(alpha: 0.2)
                                                  : AppColors.statusAmberBg,
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isUpdating)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                else
                  Semantics(
                    button: true,
                    label: 'More actions for ${item.name}',
                    child: IconButton(
                      tooltip: 'More actions for ${item.name}',
                      onPressed: () async {
                        final action = await showPantryItemActionsSheet(
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
                      icon: const Icon(Icons.more_vert_rounded, size: 22),
                      color: colorScheme.onSurface,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Quantity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
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
                        child: PantryQuantityStepper(
                          quantityLabel: item.quantityLabel,
                          canDecrement: canDecrement,
                          isUpdating: isUpdating,
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
