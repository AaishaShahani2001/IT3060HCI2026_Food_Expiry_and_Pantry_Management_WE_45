import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';

enum _ItemAction { edit, delete }

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final ValueChanged<bool> onPurchasedChanged;
  final ValueChanged<int> onQuantityChanged;
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
    required this.onQuantityChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onLongPress,
    required this.onSelectionTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.enabled = true,
  });

  Widget _quantityControl(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease quantity of ${item.name}',
            onPressed: enabled && item.quantity > 1
                ? () => onQuantityChanged(item.quantity - 1)
                : null,
            icon: const Icon(Icons.remove, size: 20),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          Semantics(
            label: 'Quantity: ${item.quantity}',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 30),
              child: Text(
                '${item.quantity}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity of ${item.name}',
            onPressed: enabled && item.quantity < 100
                ? () => onQuantityChanged(item.quantity + 1)
                : null,
            icon: const Icon(Icons.add, size: 20),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final leading = selectionMode
        ? IconButton(
            onPressed: enabled ? onSelectionTap : null,
            tooltip:
                '${isSelected ? 'Deselect' : 'Select'} ${item.name} for deletion',
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
            color: colors.primary,
          )
        : Checkbox(
            value: item.isPurchased,
            onChanged: enabled
                ? (value) => onPurchasedChanged(value ?? false)
                : null,
            activeColor: colors.primary,
            semanticLabel: 'Purchased ${item.name}',
          );
    final menu = PopupMenuButton<_ItemAction>(
      tooltip: 'Actions for ${item.name}',
      enabled: enabled,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        if (action == _ItemAction.edit) {
          onEdit();
        } else {
          onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ItemAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 12),
              Text('Edit item'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ItemAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20),
              SizedBox(width: 12),
              Text('Delete item'),
            ],
          ),
        ),
      ],
    );
    final name = Text(
      item.name,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: item.isPurchased ? colors.onSurfaceVariant : colors.onSurface,
        fontWeight: FontWeight.w500,
        decoration: item.isPurchased ? TextDecoration.lineThrough : null,
      ),
    );

    return Semantics(
      selected: selectionMode ? isSelected : null,
      child: Material(
        color: isSelected
            ? colors.secondaryContainer
            : colors.surfaceContainerHighest,
        child: InkWell(
          onLongPress: enabled ? onLongPress : null,
          onTap: !enabled
              ? null
              : selectionMode
              ? onSelectionTap
              : () => onPurchasedChanged(!item.isPurchased),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep 48px controls and readable names on narrow/large-text screens.
                final stacked =
                    constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 48, height: 48, child: leading),
                        Expanded(child: name),
                        if (!selectionMode && !stacked) ...[
                          const SizedBox(width: 8),
                          _quantityControl(context),
                        ],
                        if (!selectionMode)
                          SizedBox(width: 48, height: 48, child: menu),
                      ],
                    ),
                    if (!selectionMode && stacked)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 8,
                          top: 4,
                          bottom: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _quantityControl(context),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
