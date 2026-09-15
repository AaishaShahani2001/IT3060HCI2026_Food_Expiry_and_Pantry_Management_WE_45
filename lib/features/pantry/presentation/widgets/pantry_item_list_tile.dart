import 'package:flutter/material.dart';

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
    final canDecrement = !isUpdating;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.category.icon,
                                    size: 20,
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.category.label} · ${item.location.label}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
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
                if (isUpdating)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 148, maxWidth: 196),
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
          ],
        ),
      ),
    );
  }
}
