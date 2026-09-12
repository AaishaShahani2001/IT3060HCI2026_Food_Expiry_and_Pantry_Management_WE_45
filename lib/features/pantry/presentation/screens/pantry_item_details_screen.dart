import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../expiry/domain/services/expiry_service.dart';
import '../../../expiry/presentation/providers/expiry_provider.dart';
import '../../../shopping/domain/models/shopping_item.dart';
import '../../../shopping/presentation/providers/shopping_providers.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/utils/expiry_status.dart';
import '../providers/pantry_providers.dart';
import '../widgets/expiry_status_indicator.dart';
import '../widgets/mark_consumed_bottom_sheet.dart';
import '../widgets/pantry_item_dialogs.dart';
import 'pantry_item_form_screen.dart';

/// Local pantry item details screen.
///
/// Reads the selected item from Riverpod so quantity and edit changes
/// appear immediately. Edit and Delete stay in the app bar. The bottom
/// actions add the item to the local shopping list or subtract a consumed
/// quantity from the current stock.
class PantryItemDetailsScreen extends ConsumerStatefulWidget {
  const PantryItemDetailsScreen({required this.item, super.key});

  /// Item passed from the pantry card; the live copy is resolved from state.
  final PantryItem item;

  @override
  ConsumerState<PantryItemDetailsScreen> createState() =>
      _PantryItemDetailsScreenState();
}

class _PantryItemDetailsScreenState
    extends ConsumerState<PantryItemDetailsScreen> {
  /// True after a local delete/consume so we do not pop twice.
  bool _isLeaving = false;

  /// Prefers the latest provider copy so edits and quantity stay in sync.
  PantryItem? _resolveItem() {
    final items = ref.watch(pantryItemsProvider).asData?.value;
    if (items == null) return widget.item;

    for (final item in items) {
      if (item.id == widget.item.id) return item;
    }
    return null;
  }

  /// Opens the existing Edit Item form with the current local values.
  Future<void> _openEdit(PantryItem item) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantryItemFormScreen(item: item)),
    );
  }

  /// App-bar delete: confirm, remove from local pantry, then go back.
  Future<void> _confirmDelete(PantryItem item) async {
    final confirmed = await confirmDeletePantryItem(
      context,
      itemName: item.name,
    );
    if (!confirmed || !mounted) return;

    _isLeaving = true;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await ref.read(pantryItemsProvider.notifier).deleteItem(item.id);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text('${item.name} removed from your pantry'),
      ),
    );

    if (mounted) {
      navigator.pop();
    }
  }

  /// Copies this pantry item into the local shopping list if it is not there.
  Future<void> _addToShoppingList(PantryItem item) async {
    final shoppingItems =
        ref.read(shoppingItemsProvider).asData?.value ?? const <ShoppingItem>[];
    final alreadyListed = shoppingItems.any(
      (entry) =>
          !entry.isCompleted &&
          entry.name.toLowerCase() == item.name.toLowerCase(),
    );

    if (alreadyListed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text('${item.name} is already on your shopping list'),
        ),
      );
      return;
    }

    try {
      await ref
          .read(shoppingItemsProvider.notifier)
          .addItem(
            ShoppingItem(
              id: '',
              name: item.name,
              quantity: item.quantity > 0 ? item.quantity : 1,
              unit: item.unit.displayLabel(item.quantity),
              priority:
                  item.isLowStock ||
                      item.expiryStatus == ExpiryStatus.expired ||
                      item.expiryStatus == ExpiryStatus.expiringSoon
                  ? ShoppingItemPriority.high
                  : ShoppingItemPriority.medium,
            ),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text('${item.name} added to your shopping list'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.statusRed,
          content: Text(error.toString()),
        ),
      );
    }
  }

  /// Opens a sheet to choose how much was consumed, then updates local quantity.
  Future<void> _markConsumed(PantryItem item) async {
    if (item.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text('No ${item.name} left to consume'),
        ),
      );
      return;
    }

    final consumed = await MarkConsumedBottomSheet.show(context, item);
    if (consumed == null || consumed <= 0 || !mounted) return;

    try {
      await ref
          .read(pantryItemsProvider.notifier)
          .adjustQuantity(item.id, -consumed);

      if (!mounted) return;
      final remaining = (item.quantity - consumed).clamp(0.0, double.infinity);
      final remainingLabel =
          '${remaining == remaining.roundToDouble() ? remaining.toInt() : remaining} ${item.unit.displayLabel(remaining)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            remaining <= 0
                ? 'Consumed all ${item.quantityLabel}'
                : 'Consumed ${_formatConsumed(consumed, item)}. $remainingLabel remaining',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.statusRed,
          content: Text(error.toString()),
        ),
      );
    }
  }

  String _formatConsumed(double consumed, PantryItem item) {
    final amount = consumed == consumed.roundToDouble()
        ? consumed.toInt().toString()
        : consumed.toString();
    return '$amount ${item.unit.displayLabel(consumed)}';
  }

  /// Quantity stepper handler; never lets the local quantity go below zero.
  Future<void> _adjustQuantity(PantryItem item, double delta) async {
    final nextQuantity = item.quantity + delta;
    if (nextQuantity < 0) return;

    try {
      await ref
          .read(pantryItemsProvider.notifier)
          .adjustQuantity(item.id, delta);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.statusRed,
          content: Text(error.toString()),
        ),
      );
    }
  }

  /// Builds the expiry help line from existing expiry-service day counts.
  String _expiryHelpMessage(PantryItem item, ExpiryService expiryService) {
    final days = expiryService.daysUntilExpiry(item);

    if (days == null) return 'Expiry date not available';
    if (days < 0) {
      final overdue = days.abs();
      return overdue == 1 ? 'Expired 1 day ago' : 'Expired $overdue days ago';
    }
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    if (item.expiryStatus == ExpiryStatus.fresh) {
      return 'Fresh for $days more days';
    }
    return 'Expires in $days days';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Safe price label for older in-memory items that may still have a null price.
  String _priceLabelFor(PantryItem item) {
    try {
      return item.priceLabel;
    } catch (_) {
      return 'Rs. 0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _resolveItem();

    // Item was consumed or deleted elsewhere; leave this screen safely.
    if (item == null) {
      if (!_isLeaving) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isLeaving) {
            Navigator.of(context).pop();
          }
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }

    final expiryService = ref.watch(expiryServiceProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final canDecrement = item.quantity > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Edit / Delete remain here so the bottom actions can be shopping/consume.
        actions: [
          IconButton(
            onPressed: () => _openEdit(item),
            tooltip: 'Edit ${item.name}',
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.primaryDark,
          ),
          IconButton(
            onPressed: () => _confirmDelete(item),
            tooltip: 'Delete ${item.name}',
            icon: const Icon(Icons.delete_outline),
            color: AppColors.statusRed,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name, category placeholder image, and expiry badge.
                  _HeaderCard(item: item),
                  const SizedBox(height: 16),
                  // Compact label/value rows, including price.
                  _InfoCard(
                    item: item,
                    isWide: isWide,
                    priceLabel: _priceLabelFor(item),
                    purchaseDateLabel: item.createdAt == null
                        ? null
                        : _formatDate(item.createdAt!),
                    expiryDateLabel: item.expiryDate == null
                        ? null
                        : _formatDate(item.expiryDate!),
                  ),
                  const SizedBox(height: 16),
                  _ExpiryCard(
                    item: item,
                    expiryDateLabel: item.expiryDate == null
                        ? 'Expiry date not available'
                        : _formatDate(item.expiryDate!),
                    helpMessage: _expiryHelpMessage(item, expiryService),
                  ),
                  const SizedBox(height: 16),
                  _QuantityCard(
                    item: item,
                    canDecrement: canDecrement,
                    onDecrement: () =>
                        _adjustQuantity(item, -item.quantityStep),
                    onIncrement: () => _adjustQuantity(item, item.quantityStep),
                  ),
                  const SizedBox(height: 24),
                  // Bottom actions: restock via shopping list, or mark as used.
                  FilledButton.icon(
                    onPressed: () => _addToShoppingList(item),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Add shopping list'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: item.quantity <= 0
                        ? null
                        : () => _markConsumed(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark consumed'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header: category icon placeholder, name, category, and status badge.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              item.category.icon,
              size: 40,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      item.category.icon,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ExpiryStatusBadge(status: item.expiryStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Item facts in a compact side-by-side label / value layout.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.item,
    required this.isWide,
    required this.priceLabel,
    required this.purchaseDateLabel,
    required this.expiryDateLabel,
  });

  final PantryItem item;
  final bool isWide;
  final String priceLabel;
  final String? purchaseDateLabel;
  final String? expiryDateLabel;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoRow(
        icon: Icons.payments_outlined,
        label: 'Price',
        value: priceLabel,
      ),
      _InfoRow(
        icon: Icons.inventory_2_outlined,
        label: 'Quantity',
        value: item.quantityLabel,
      ),
      _InfoRow(
        icon: item.location.icon,
        label: 'Storage location',
        value: item.location.label,
      ),
      if (purchaseDateLabel != null)
        _InfoRow(
          icon: Icons.shopping_bag_outlined,
          label: 'Purchase date',
          value: purchaseDateLabel!,
        ),
      if (expiryDateLabel != null)
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Expiry date',
          value: expiryDateLabel!,
        ),
      _InfoRow(
        icon: item.category.icon,
        label: 'Category',
        value: item.category.label,
      ),
    ];

    final pairedRows = <Widget>[];
    for (var i = 0; i < rows.length; i += 2) {
      final left = rows[i];
      final right = i + 1 < rows.length ? rows[i + 1] : null;
      if (isWide && right != null) {
        pairedRows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          ),
        );
      } else {
        pairedRows.add(left);
        if (!isWide && right != null) pairedRows.add(right);
      }
    }

    return _DetailsCard(child: Column(children: pairedRows));
  }
}

/// Expiry date plus a status message from the shared expiry helpers.
class _ExpiryCard extends StatelessWidget {
  const _ExpiryCard({
    required this.item,
    required this.expiryDateLabel,
    required this.helpMessage,
  });

  final PantryItem item;
  final String expiryDateLabel;
  final String helpMessage;

  @override
  Widget build(BuildContext context) {
    final status = item.expiryStatus;

    return _DetailsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                color: status.foregroundColor,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Expiry information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading,
                  ),
                ),
              ),
              ExpiryStatusIndicator(status: status, size: 12),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Expiry date',
            value: expiryDateLabel,
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: status.backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(status.icon, size: 20, color: status.foregroundColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    helpMessage,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: status.foregroundColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Local +/- quantity controls. Changes write back through pantryItemsProvider.
class _QuantityCard extends StatelessWidget {
  const _QuantityCard({
    required this.item,
    required this.canDecrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final PantryItem item;
  final bool canDecrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quantity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.quantityLabel,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softGreen.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                _QuantityButton(
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.quantityLabel,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                _QuantityButton(
                  icon: Icons.add,
                  tooltip: 'Increase quantity',
                  enabled: true,
                  foreground: AppColors.primaryDark,
                  onPressed: onIncrement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
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
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              size: 20,
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

/// One details row: label on the left, value on the right.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: AppColors.heading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared white card chrome used by every section on this screen.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
