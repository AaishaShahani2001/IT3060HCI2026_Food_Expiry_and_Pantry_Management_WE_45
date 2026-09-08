import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/shopping_item.dart';
import '../providers/shopping_providers.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(shoppingItemsProvider);
    final filteredItems = ref.watch(filteredShoppingItemsProvider);
    final summary = ref.watch(shoppingSummaryProvider);
    final filters = ref.watch(shoppingFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'Shopping List',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.darkGreen,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Clear filters',
            onPressed: filters.hasActiveFilters
                ? () {
                    ref.read(shoppingFilterProvider.notifier).clearFilters();

                    _searchController.clear();
                    setState(() {});
                  }
                : null,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showShoppingItemForm(context),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return ref.read(shoppingItemsProvider.notifier).refreshItems();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            _buildSummary(summary),
            const SizedBox(height: 18),
            _buildSearchField(),
            const SizedBox(height: 12),
            _buildFilters(filters),
            const SizedBox(height: 18),
            itemsAsync.when(
              data: (_) => _buildItemsList(filteredItems),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _buildErrorState(error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(({int total, int completed, int pending}) summary) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Total',
            value: summary.total.toString(),
            icon: Icons.shopping_cart_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Pending',
            value: summary.pending.toString(),
            icon: Icons.pending_actions_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Purchased',
            value: summary.completed.toString(),
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.mediumGreen),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        ref.read(shoppingFilterProvider.notifier).setSearchQuery(value.trim());

        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Search shopping list',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();

                  ref.read(shoppingFilterProvider.notifier).setSearchQuery('');

                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        filled: true,
        fillColor: AppColors.white,
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

  Widget _buildFilters(ShoppingFilterState filters) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<ShoppingItemPriority?>(
            initialValue: filters.priority,
            decoration: InputDecoration(
              labelText: 'Priority',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
            ),
            items: [
              const DropdownMenuItem<ShoppingItemPriority?>(
                value: null,
                child: Text('All priorities'),
              ),
              ...ShoppingItemPriority.values.map(
                (priority) => DropdownMenuItem<ShoppingItemPriority?>(
                  value: priority,
                  child: Text(priority.label),
                ),
              ),
            ],
            onChanged: (value) {
              ref.read(shoppingFilterProvider.notifier).setPriority(value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            tileColor: AppColors.white,
            title: const Text(
              'Purchased',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            value: filters.showCompleted,
            onChanged: (value) {
              ref.read(shoppingFilterProvider.notifier).setShowCompleted(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(List<ShoppingItem> items) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return Column(children: items.map(_buildShoppingItemCard).toList());
  }

  Widget _buildShoppingItemCard(ShoppingItem item) {
    final priorityColor = _priorityColor(item.priority);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(item),
      onDismissed: (_) {
        ref.read(shoppingItemsProvider.notifier).deleteItem(item.id);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.statusRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isCompleted
                ? AppColors.indicatorInactive
                : AppColors.cardBorder,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          leading: Checkbox(
            value: item.isCompleted,
            activeColor: AppColors.primaryGreen,
            onChanged: (_) {
              ref.read(shoppingItemsProvider.notifier).toggleCompleted(item.id);
            },
          ),
          title: Text(
            item.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: item.isCompleted
                  ? AppColors.textSecondary
                  : AppColors.darkGreen,
              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Text(
                  item.quantityLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.priority.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showShoppingItemForm(context, item: item);
              } else if (value == 'delete') {
                _deleteItem(item);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filters = ref.read(shoppingFilterProvider);

    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            filters.hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.shopping_cart_outlined,
            size: 52,
            color: AppColors.mediumGreen,
          ),
          const SizedBox(height: 14),
          Text(
            filters.hasActiveFilters
                ? 'No matching items'
                : 'Your shopping list is empty',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            filters.hasActiveFilters
                ? 'Try changing your search or filters.'
                : 'Add items you need to buy.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 46, color: AppColors.statusRed),
          const SizedBox(height: 12),
          const Text(
            'Unable to load shopping list',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(shoppingItemsProvider.notifier).refreshItems();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(ShoppingItemPriority priority) {
    switch (priority) {
      case ShoppingItemPriority.low:
        return AppColors.statusFresh;
      case ShoppingItemPriority.medium:
        return AppColors.statusAmber;
      case ShoppingItemPriority.high:
        return AppColors.statusRed;
    }
  }

  Future<bool> _confirmDelete(ShoppingItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text('Remove "${item.name}" from your shopping list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    final confirmed = await _confirmDelete(item);

    if (!confirmed || !mounted) return;

    await ref.read(shoppingItemsProvider.notifier).deleteItem(item.id);
  }

  Future<void> _showShoppingItemForm(
    BuildContext context, {
    ShoppingItem? item,
  }) async {
    final nameController = TextEditingController(text: item?.name ?? '');

    final quantityController = TextEditingController(
      text: item == null
          ? '1'
          : item.quantity == item.quantity.roundToDouble()
          ? item.quantity.toInt().toString()
          : item.quantity.toString(),
    );

    String unit = item?.unit ?? 'items';

    ShoppingItemPriority priority =
        item?.priority ?? ShoppingItemPriority.medium;

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null
                            ? 'Add Shopping Item'
                            : 'Edit Shopping Item',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Item name',
                          hintText: 'e.g. Milk',
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter an item name';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                filled: true,
                                fillColor: AppColors.white,
                              ),
                              validator: (value) {
                                final quantity = double.tryParse(value ?? '');

                                if (quantity == null || quantity <= 0) {
                                  return 'Enter a valid quantity';
                                }

                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: unit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                filled: true,
                                fillColor: AppColors.white,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'items',
                                  child: Text('Items'),
                                ),
                                DropdownMenuItem(
                                  value: 'kg',
                                  child: Text('kg'),
                                ),
                                DropdownMenuItem(value: 'g', child: Text('g')),
                                DropdownMenuItem(
                                  value: 'liters',
                                  child: Text('Liters'),
                                ),
                                DropdownMenuItem(
                                  value: 'ml',
                                  child: Text('ml'),
                                ),
                                DropdownMenuItem(
                                  value: 'packs',
                                  child: Text('Packs'),
                                ),
                                DropdownMenuItem(
                                  value: 'bottles',
                                  child: Text('Bottles'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(() {
                                    unit = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ShoppingItemPriority>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        items: ShoppingItemPriority.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              priority = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            final quantity = double.parse(
                              quantityController.text.trim(),
                            );

                            final notifier = ref.read(
                              shoppingItemsProvider.notifier,
                            );

                            if (item == null) {
                              await notifier.addItem(
                                ShoppingItem(
                                  id: '',
                                  name: nameController.text.trim(),
                                  quantity: quantity,
                                  unit: unit,
                                  priority: priority,
                                ),
                              );
                            } else {
                              await notifier.updateItem(
                                item.copyWith(
                                  name: nameController.text.trim(),
                                  quantity: quantity,
                                  unit: unit,
                                  priority: priority,
                                ),
                              );
                            }

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                          icon: Icon(
                            item == null ? Icons.add : Icons.save_outlined,
                          ),
                          label: Text(
                            item == null
                                ? 'Add to Shopping List'
                                : 'Save Changes',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
  }
}
