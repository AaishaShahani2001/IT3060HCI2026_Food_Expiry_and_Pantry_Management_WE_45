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
import '../utils/pantry_item_actions.dart';
import '../widgets/expiry_status_indicator.dart';
import '../widgets/mark_consumed_bottom_sheet.dart';
import '../widgets/pantry_item_actions_sheet.dart';

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
    final pending = ref.watch(pantryPendingQuantitiesProvider);
    PantryItem? found = widget.item;
    if (items != null) {
      found = null;
      final firestoreId = widget.item.firestoreId;
      for (final item in items) {
        if (firestoreId != null &&
            firestoreId.isNotEmpty &&
            item.firestoreId == firestoreId) {
          found = item;
          break;
        }
        if (item.id == widget.item.id) {
          found = item;
          break;
        }
      }
    }
    if (found == null) return null;
    final overlay = pending[found.id];
    if (overlay != null) return found.copyWith(quantity: overlay);
    return found;
  }

  Future<void> _openEdit(PantryItem item) {
    return openPantryItemEditor(context, item);
  }

  Future<void> _openActions(PantryItem item) async {
    if (ref.read(pantryBusyItemIdsProvider).contains(item.id)) return;
    final action = await showPantryItemActionsSheet(
      context: context,
      item: item,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case PantryItemSheetAction.edit:
        await _openEdit(item);
      case PantryItemSheetAction.usedUp:
        await _markUsedUp(item);
      case PantryItemSheetAction.delete:
        await _confirmDelete(item);
    }
  }

  Future<void> _markUsedUp(PantryItem item) {
    final items = ref.read(pantryItemsProvider).asData?.value ?? const [];
    final index = items.indexWhere((entry) => entry.id == item.id);
    return handlePantryUsedUp(
      context: context,
      ref: ref,
      item: item,
      originalIndex: index < 0 ? 0 : index,
      onRemoved: () {
        _isLeaving = true;
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  /// App-bar delete: confirm, delete from Firestore, then leave this screen.
  Future<void> _confirmDelete(PantryItem item) async {
    if (ref.read(pantryBusyItemIdsProvider).contains(item.id)) return;
    await handlePantryPermanentDelete(
      context: context,
      ref: ref,
      item: item,
      onRemoved: () {
        _isLeaving = true;
        if (mounted) Navigator.of(context).pop();
      },
    );
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

  /// Opens a sheet to choose how much was consumed, then writes to Firestore.
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

    final result = await MarkConsumedBottomSheet.show(context, item);
    if (result == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          result.remaining <= 0
              ? 'All ${item.name} consumed. Item is now out of stock.'
              : 'Consumed ${_formatConsumed(result.consumed, item)}. ${_formatQuantityValue(result.remaining)} remaining.',
        ),
      ),
    );
  }

  String _formatConsumed(double consumed, PantryItem item) {
    return '${_formatQuantityValue(consumed)} ${item.unit.displayLabel(consumed)}';
  }

  String _formatQuantityValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Quantity stepper with optimistic UI, debounce, and Undo.
  Future<void> _adjustQuantity(PantryItem item, double delta) {
    return handlePantryQuantityDelta(
      context: context,
      ref: ref,
      item: item,
      delta: delta,
    );
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
    final isUpdating = ref.watch(pantryBusyItemIdsProvider).contains(item.id);
    final canDecrement = !isUpdating;

    return Scaffold(
      backgroundColor: FreshPalette.pageBackground,
      appBar: AppBar(
        backgroundColor: FreshPalette.pageBackground,
        foregroundColor: FreshPalette.heading,
        surfaceTintColor: FreshPalette.pageBackground,
        title: const Text('Item Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Edit / Delete remain here so the bottom actions can be shopping/consume.
        actions: [
          if (ref.watch(pantryBusyItemIdsProvider).contains(item.id))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: FreshPalette.selected,
                  ),
                ),
              ),
            )
          else
            Semantics(
              button: true,
              label: 'More actions for ${item.name}',
              child: IconButton(
                onPressed: () => _openActions(item),
                tooltip: 'More actions for ${item.name}',
                icon: const Icon(Icons.more_vert_rounded),
                color: FreshPalette.heading,
              ),
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
                    isUpdating: isUpdating,
                    onDecrement: () =>
                        _adjustQuantity(item, -item.quantityStep),
                    onIncrement: isUpdating
                        ? null
                        : () => _adjustQuantity(item, item.quantityStep),
                  ),
                  const SizedBox(height: 24),
                  // Bottom actions: restock via shopping list, or mark as used.
                  FilledButton.icon(
                    onPressed: () => _addToShoppingList(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: FreshPalette.primaryButton,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Add shopping list'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: item.quantity <= 0 || isUpdating
                        ? null
                        : () => _markConsumed(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FreshPalette.selected,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: FreshPalette.selected),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      item.isOutOfStock ? 'Out of stock' : 'Mark consumed',
                    ),
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
              color: FreshPalette.highlight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              item.category.icon,
              size: 40,
              color: FreshPalette.selected,
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
                    color: FreshPalette.heading,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      item.category.icon,
                      size: 16,
                      color: FreshPalette.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: FreshPalette.secondaryText,
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
                    color: FreshPalette.heading,
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
    required this.isUpdating,
    required this.onDecrement,
    required this.onIncrement,
  });

  final PantryItem item;
  final bool canDecrement;
  final bool isUpdating;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;

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
              color: FreshPalette.heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.isOutOfStock ? 'Out of stock' : item.quantityLabel,
            style: TextStyle(
              fontSize: 14,
              color: item.isOutOfStock
                  ? AppColors.statusRed
                  : FreshPalette.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: FreshPalette.highlight.withValues(alpha: 0.55),
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
                  foreground: FreshPalette.heading,
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
                      child: isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: FreshPalette.selected,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.quantityLabel,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: FreshPalette.heading,
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
                  enabled: onIncrement != null && !isUpdating,
                  foreground: FreshPalette.selected,
                  onPressed: onIncrement ?? () {},
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
                  : FreshPalette.secondaryText.withValues(alpha: 0.35),
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
          Icon(icon, size: 18, color: FreshPalette.selected),
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
                color: FreshPalette.secondaryText,
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
                color: FreshPalette.heading,
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
        color: FreshPalette.card,
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
