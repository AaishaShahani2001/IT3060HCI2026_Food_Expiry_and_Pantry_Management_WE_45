import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final ValueChanged<bool> onPurchasedChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final VoidCallback onSelectionTap;
  final bool selectionMode;
  final bool isSelected;
  final bool enabled;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onPurchasedChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onLongPress,
    required this.onSelectionTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: selectionMode ? isSelected : null,
      child: Material(
        color: isSelected ? AppColors.softGreen : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          enabled: enabled,
          onLongPress: enabled ? onLongPress : null,
          onTap: !enabled
              ? null
              : selectionMode
              ? onSelectionTap
              : () => onPurchasedChanged(!item.isPurchased),
          leading: selectionMode
              ? Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: AppColors.primaryGreen,
                  semanticLabel: isSelected
                      ? 'Selected for deletion'
                      : 'Not selected',
                )
              : Checkbox(
                  value: item.isPurchased,
                  onChanged: enabled
                      ? (value) => onPurchasedChanged(value ?? false)
                      : null,
                  activeColor: AppColors.primaryGreen,
                  semanticLabel: 'Purchased ${item.name}',
                ),
          trailing: selectionMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: enabled ? onEdit : null,
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.mediumGreen,
                      tooltip: 'Edit ${item.name}',
                    ),
                    IconButton(
                      onPressed: enabled ? onDelete : null,
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.unreadBadge,
                      tooltip: 'Delete ${item.name}',
                    ),
                  ],
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.indicatorInactive.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          title: Text(
            item.name,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.darkGreen,
              fontWeight: FontWeight.w600,
              decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            '${AppStrings.quantity}: ${item.quantity}',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
