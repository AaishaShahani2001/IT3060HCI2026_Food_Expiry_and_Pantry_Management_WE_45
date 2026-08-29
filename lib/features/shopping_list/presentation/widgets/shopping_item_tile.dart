import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final ValueChanged<bool> onPurchasedChanged;
  final VoidCallback onDelete;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onPurchasedChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: CheckboxListTile(
        value: item.isPurchased,
        onChanged: (value) => onPurchasedChanged(value ?? false),
        activeColor: AppColors.primaryGreen,
        controlAffinity: ListTileControlAffinity.leading,
        secondary: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          color: AppColors.unreadBadge,
          tooltip: 'Delete ${item.name}',
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.indicatorInactive.withValues(alpha: 0.5),
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
    );
  }
}
