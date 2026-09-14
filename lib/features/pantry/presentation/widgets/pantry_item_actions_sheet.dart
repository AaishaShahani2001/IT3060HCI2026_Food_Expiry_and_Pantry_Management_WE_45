import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';

enum PantryItemSheetAction { edit, usedUp, delete }

/// Material 3 actions sheet for a pantry item card.
Future<PantryItemSheetAction?> showPantryItemActionsSheet({
  required BuildContext context,
  required PantryItem item,
}) {
  return showModalBottomSheet<PantryItemSheetAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FreshPalette.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: FreshPalette.heading,
                      ),
                    ),
                  ),
                ),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  iconColor: FreshPalette.selected,
                  title: 'Edit Item',
                  subtitle: 'Update item information',
                  onTap: () =>
                      Navigator.of(context).pop(PantryItemSheetAction.edit),
                ),
                _ActionTile(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.primaryGreen,
                  title: 'Used Up',
                  subtitle: 'Remove because this item was consumed',
                  onTap: () =>
                      Navigator.of(context).pop(PantryItemSheetAction.usedUp),
                ),
                const Divider(height: 24),
                _ActionTile(
                  icon: Icons.delete_outline,
                  iconColor: AppColors.statusRed,
                  title: 'Delete Item',
                  subtitle: 'Remove an incorrect or unwanted entry',
                  titleColor: AppColors.statusRed,
                  onTap: () =>
                      Navigator.of(context).pop(PantryItemSheetAction.delete),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 12,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? FreshPalette.heading,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: FreshPalette.secondaryText),
      ),
      onTap: onTap,
    );
  }
}
