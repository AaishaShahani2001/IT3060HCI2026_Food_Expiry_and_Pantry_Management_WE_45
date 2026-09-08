import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(pantryItemsProvider);
    final filteredItems = ref.watch(filteredPantryItemsProvider);
    final summary = ref.watch(pantrySummaryProvider);
    final locationCounts = ref.watch(pantryLocationCountsProvider);
    final filters = ref.watch(pantryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'My Pantry',
          style: TextStyle(
            color: AppColors.darkGreen,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(pantryItemsProvider.notifier).refreshItems();
            },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.darkGreen),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => _showPantryItemForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Item',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: itemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () {
            ref.read(pantryItemsProvider.notifier).refreshItems();
          },
        ),
        data: (_) => RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () {
            return ref.read(pantryItemsProvider.notifier).refreshItems();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            children: [
              _SummaryCard(total: summary.total, lowStock: summary.lowStock),
              const SizedBox(height: 16),
              _SearchBar(
                value: filters.searchQuery,
                onChanged: (value) {
                  ref.read(pantryFilterProvider.notifier).setSearchQuery(value);
                },
              ),
              const SizedBox(height: 16),
              _LocationTabs(
                selectedLocation: filters.selectedLocation,
                counts: locationCounts,
                onSelected: (location) {
                  ref.read(pantryFilterProvider.notifier).setLocation(location);
                },
              ),
              const SizedBox(height: 14),
              _FilterRow(
                selectedCategory: filters.selectedCategory,
                stockLevel: filters.stockLevel,
                onCategoryChanged: (category) {
                  ref.read(pantryFilterProvider.notifier).setCategory(category);
                },
                onStockChanged: (stock) {
                  ref.read(pantryFilterProvider.notifier).setStockLevel(stock);
                },
                onClear: () {
                  ref.read(pantryFilterProvider.notifier).clearFilters();
                },
                hasActiveFilters: filters.hasActiveFilters,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pantry Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredItems.length} item${filteredItems.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredItems.isEmpty)
                const _EmptyPantryView()
              else
                ...filteredItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PantryItemCard(
                      item: item,
                      onIncrease: () {
                        ref
                            .read(pantryItemsProvider.notifier)
                            .adjustQuantity(item.id, item.quantityStep);
                      },
                      onDecrease: () {
                        ref
                            .read(pantryItemsProvider.notifier)
                            .adjustQuantity(item.id, -item.quantityStep);
                      },
                      onEdit: () {
                        _showPantryItemForm(context, ref, existingItem: item);
                      },
                      onDelete: () {
                        _confirmDelete(context, ref, item);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPantryItemForm(
    BuildContext context,
    WidgetRef ref, {
    PantryItem? existingItem,
  }) async {
    final result = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PantryItemForm(existingItem: existingItem);
      },
    );

    if (result == null) return;

    try {
      if (existingItem == null) {
        await ref.read(pantryItemsProvider.notifier).addItem(result);
      } else {
        await ref.read(pantryItemsProvider.notifier).updateItem(result);
      }
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingItem == null
                ? 'Unable to add item.'
                : 'Unable to update item.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PantryItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text(
            'Are you sure you want to remove "${item.name}" from your pantry?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusRed,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref.read(pantryItemsProvider.notifier).deleteItem(item.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} removed from pantry.')),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete item.')));
    }
  }
}

// -----------------------------------------------------------------------------
// SUMMARY
// -----------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.lowStock});

  final int total;
  final int lowStock;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.inventory_2_outlined,
            value: '$total',
            label: 'Total items',
            background: AppColors.softGreen,
            iconColor: AppColors.mediumGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.warning_amber_rounded,
            value: '$lowStock',
            label: 'Low stock',
            background: AppColors.statusAmberBg,
            iconColor: AppColors.statusAmber,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.background,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

// -----------------------------------------------------------------------------
// SEARCH
// -----------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search pantry items...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.mediumGreen,
        ),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                onPressed: () => onChanged(''),
                icon: const Icon(Icons.clear_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOCATION TABS
// -----------------------------------------------------------------------------

class _LocationTabs extends StatelessWidget {
  const _LocationTabs({
    required this.selectedLocation,
    required this.counts,
    required this.onSelected,
  });

  final PantryLocation? selectedLocation;
  final Map<PantryLocation?, int> counts;
  final ValueChanged<PantryLocation?> onSelected;

  @override
  Widget build(BuildContext context) {
    final locations = <PantryLocation?>[
      null,
      PantryLocation.refrigerator,
      PantryLocation.freezer,
      PantryLocation.pantry,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: locations.map((location) {
          final selected = selectedLocation == location;
          final count = counts[location] ?? 0;

          final label = location == null ? 'All' : location.label;

          final icon = location == null
              ? Icons.grid_view_rounded
              : location.icon;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(location),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryGreen
                        : AppColors.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? Colors.white : AppColors.mediumGreen,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.darkGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppColors.softGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.darkGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FILTERS
// -----------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedCategory,
    required this.stockLevel,
    required this.onCategoryChanged,
    required this.onStockChanged,
    required this.onClear,
    required this.hasActiveFilters,
  });

  final PantryCategory? selectedCategory;
  final StockLevelFilter stockLevel;
  final ValueChanged<PantryCategory?> onCategoryChanged;
  final ValueChanged<StockLevelFilter> onStockChanged;
  final VoidCallback onClear;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PopupMenuButton<PantryCategory?>(
          onSelected: onCategoryChanged,
          itemBuilder: (context) {
            return [
              const PopupMenuItem<PantryCategory?>(
                value: null,
                child: Text('All categories'),
              ),
              ...PantryCategory.values.map(
                (category) => PopupMenuItem<PantryCategory?>(
                  value: category,
                  child: Text(category.label),
                ),
              ),
            ];
          },
          child: _FilterChip(
            icon: Icons.category_outlined,
            label: selectedCategory?.label ?? 'Category',
            selected: selectedCategory != null,
          ),
        ),
        PopupMenuButton<StockLevelFilter>(
          initialValue: stockLevel,
          onSelected: onStockChanged,
          itemBuilder: (context) {
            return StockLevelFilter.values
                .map(
                  (level) => PopupMenuItem<StockLevelFilter>(
                    value: level,
                    child: Text(level.label),
                  ),
                )
                .toList();
          },
          child: _FilterChip(
            icon: Icons.inventory_2_outlined,
            label: stockLevel == StockLevelFilter.all
                ? 'Stock level'
                : stockLevel.label,
            selected: stockLevel != StockLevelFilter.all,
          ),
        ),
        if (hasActiveFilters)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all_rounded, size: 18),
            label: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: AppColors.statusRed),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.softGreen : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: selected ? AppColors.primaryGreen : AppColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.mediumGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.darkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ITEM CARD
// -----------------------------------------------------------------------------

class _PantryItemCard extends StatelessWidget {
  const _PantryItemCard({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onEdit,
    required this.onDelete,
  });

  final PantryItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = item.expiryStatus;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.category.icon, color: status.color, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category.label} • ${item.location.label}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          item.location.icon,
                          size: 14,
                          color: AppColors.mediumGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.location.label,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.statusRed,
                        ),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuantityControl(
                  item: item,
                  onIncrease: onIncrease,
                  onDecrease: onDecrease,
                ),
              ),
              const SizedBox(width: 12),
              _ExpiryBadge(status: status, expiryDate: item.expiryDate),
            ],
          ),
          if (item.isLowStock) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusAmberBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: AppColors.statusAmber,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Low stock — consider adding this to your shopping list.',
                    style: TextStyle(
                      color: AppColors.statusAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// QUANTITY
// -----------------------------------------------------------------------------

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
  });

  final PantryItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: item.quantity <= 0 ? null : onDecrease,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.softGreen,
            foregroundColor: AppColors.darkGreen,
          ),
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        Expanded(
          child: Center(
            child: Column(
              children: [
                Text(
                  item.quantityValueLabel,
                  style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item.unit.displayLabel(item.quantity),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onIncrease,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.softGreen,
            foregroundColor: AppColors.darkGreen,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// EXPIRY BADGE
// -----------------------------------------------------------------------------

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.status, required this.expiryDate});

  final dynamic status;
  final DateTime? expiryDate;

  String _dateText() {
    if (expiryDate == null) {
      return 'Expiry unknown';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
    );

    final days = expiry.difference(today).inDays;

    if (days < 0) {
      final count = days.abs();
      return count == 1 ? 'Expired 1 day ago' : 'Expired $count days ago';
    }

    if (days == 0) {
      return 'Expires today';
    }

    if (days == 1) {
      return 'Expires tomorrow';
    }

    return 'Expires in $days days';
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _dateText(),
              style: TextStyle(
                color: status.color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADD / EDIT FORM
// -----------------------------------------------------------------------------

class _PantryItemForm extends StatefulWidget {
  const _PantryItemForm({this.existingItem});

  final PantryItem? existingItem;

  @override
  State<_PantryItemForm> createState() => _PantryItemFormState();
}

class _PantryItemFormState extends State<_PantryItemForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;

  late PantryCategory _category;
  late PantryLocation _location;
  late PantryUnit _unit;
  DateTime? _expiryDate;

  bool get isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();

    final item = widget.existingItem;

    _nameController = TextEditingController(text: item?.name ?? '');

    _quantityController = TextEditingController(
      text: item == null ? '1' : item.quantityValueLabel,
    );

    _category = item?.category ?? PantryCategory.other;
    _location = item?.location ?? PantryLocation.pantry;
    _unit = item?.unit ?? PantryUnit.items;
    _expiryDate = item?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Select expiry date',
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());

    if (quantity == null || quantity < 0) {
      return;
    }

    final existing = widget.existingItem;

    final item = PantryItem(
      id: existing?.id ?? '',
      name: _nameController.text.trim(),
      category: _category,
      location: _location,
      quantity: quantity,
      unit: _unit,
      expiryDate: _expiryDate,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: const BoxConstraints(maxHeight: 760),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isEditing ? 'Edit Pantry Item' : 'Add Pantry Item',
                  style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isEditing
                      ? 'Update the details of this pantry item.'
                      : 'Add a new food item to your pantry.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Milk',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an item name.';
                    }

                    if (value.trim().length < 2) {
                      return 'Item name is too short.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PantryCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: PantryCategory.values
                            .map(
                              (category) => DropdownMenuItem<PantryCategory>(
                                value: category,
                                child: Text(category.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _category = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<PantryLocation>(
                        initialValue: _location,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                        ),
                        items: PantryLocation.values
                            .map(
                              (location) => DropdownMenuItem<PantryLocation>(
                                value: location,
                                child: Text(location.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _location = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                        validator: (value) {
                          final number = double.tryParse(value ?? '');

                          if (number == null) {
                            return 'Enter quantity.';
                          }

                          if (number < 0) {
                            return 'Cannot be negative.';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<PantryUnit>(
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: PantryUnit.values
                            .map(
                              (unit) => DropdownMenuItem<PantryUnit>(
                                value: unit,
                                child: Text(unit.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _unit = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _selectExpiryDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expiry date',
                      prefixIcon: const Icon(Icons.event_outlined),
                      suffixIcon: _expiryDate == null
                          ? null
                          : IconButton(
                              tooltip: 'Remove expiry date',
                              onPressed: () {
                                setState(() {
                                  _expiryDate = null;
                                });
                              },
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    ),
                    child: Text(
                      _expiryDate == null
                          ? 'No expiry date'
                          : _formatDate(_expiryDate!),
                      style: TextStyle(
                        color: _expiryDate == null
                            ? AppColors.textSecondary
                            : AppColors.darkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: Icon(
                      isEditing ? Icons.save_outlined : Icons.add_rounded,
                    ),
                    label: Text(
                      isEditing ? 'Save Changes' : 'Add to Pantry',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// -----------------------------------------------------------------------------
// EMPTY STATE
// -----------------------------------------------------------------------------

class _EmptyPantryView extends StatelessWidget {
  const _EmptyPantryView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 52,
            color: AppColors.mediumGreen,
          ),
          SizedBox(height: 14),
          Text(
            'No pantry items found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkGreen,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try changing your filters or add a new item to your pantry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ERROR STATE
// -----------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: AppColors.statusRed,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load pantry',
              style: TextStyle(
                color: AppColors.darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
