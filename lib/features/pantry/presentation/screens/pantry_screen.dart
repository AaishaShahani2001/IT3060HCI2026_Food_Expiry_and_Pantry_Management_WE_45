import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';
import '../widgets/expiry_status_indicator.dart';
import '../widgets/pantry_empty_state.dart';
import '../widgets/pantry_filter_bottom_sheet.dart';
import '../widgets/pantry_item_card.dart';
import '../widgets/pantry_location_selector.dart';
import 'pantry_item_form_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  bool _isSearchVisible = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openAddItem() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PantryItemFormScreen()),
    );
  }

  Future<void> _openEditItem(PantryItem item) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantryItemFormScreen(item: item)),
    );
  }

  Future<void> _confirmDelete(PantryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete item',
          style: TextStyle(
            color: AppColors.heading,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}" from your pantry?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(pantryItemsProvider.notifier).deleteItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text('${item.name} removed from your pantry'),
          ),
        );
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        ref.read(pantryFilterProvider.notifier).setSearchQuery('');
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(pantryItemsProvider);
    final filteredItems = ref.watch(filteredPantryItemsProvider);
    final filters = ref.watch(pantryFilterProvider);
    final locationCounts = ref.watch(pantryLocationCountsProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItem,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () =>
              ref.read(pantryItemsProvider.notifier).refreshItems(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, filters)),
              if (_isSearchVisible)
                SliverToBoxAdapter(child: _buildSearchField()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PantryLocationSelector(
                    selectedLocation: filters.selectedLocation,
                    locationCounts: locationCounts,
                    onLocationSelected: (location) {
                      ref
                          .read(pantryFilterProvider.notifier)
                          .setLocation(location);
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _resultsLabel(itemsAsync, filteredItems, filters),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const ExpiryStatusLegendButton(),
                      if (filters.hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _isSearchVisible = false);
                            ref
                                .read(pantryFilterProvider.notifier)
                                .clearFilters();
                          },
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                ),
              ),
              itemsAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: PantryLoadingState(),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: PantryEmptyState(
                    type: PantryEmptyStateType.error,
                    onRetry: () {
                      ref.read(pantryItemsProvider.notifier).refreshItems();
                    },
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: PantryEmptyState(
                        type: PantryEmptyStateType.noItems,
                        onPrimaryAction: _openAddItem,
                      ),
                    );
                  }

                  if (filteredItems.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: PantryEmptyState(
                        type: PantryEmptyStateType.noResults,
                        onPrimaryAction: () {
                          _searchController.clear();
                          setState(() => _isSearchVisible = false);
                          ref
                              .read(pantryFilterProvider.notifier)
                              .clearFilters();
                        },
                      ),
                    );
                  }

                  if (isTablet) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 168,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = filteredItems[index];
                          return _buildItemCard(item);
                        }, childCount: filteredItems.length),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildItemCard(filteredItems[index]);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(PantryItem item) {
    final notifier = ref.read(pantryItemsProvider.notifier);
    return PantryItemCard(
      item: item,
      onEdit: () => _openEditItem(item),
      onDelete: () => _confirmDelete(item),
      onIncrement: () => notifier.adjustQuantity(item.id, item.quantityStep),
      onDecrement: () => notifier.adjustQuantity(item.id, -item.quantityStep),
    );
  }

  Widget _buildHeader(BuildContext context, PantryFilterState filters) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Pantry',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and organize your food items',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleSearch,
            tooltip: 'Search items',
            icon: Icon(
              _isSearchVisible ? Icons.search_off_outlined : Icons.search,
              color: _isSearchVisible || filters.searchQuery.isNotEmpty
                  ? AppColors.primaryDark
                  : AppColors.heading,
            ),
          ),
          IconButton(
            onPressed: () => PantryFilterBottomSheet.show(context),
            tooltip: 'Filter items',
            icon: Badge(
              isLabelVisible: filters.hasActiveFilters,
              smallSize: 8,
              backgroundColor: AppColors.statusAmber,
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          setState(() {});
          ref.read(pantryFilterProvider.notifier).setSearchQuery(value);
        },
        decoration: InputDecoration(
          hintText: 'Search by item name...',
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryDark),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    ref.read(pantryFilterProvider.notifier).setSearchQuery('');
                  },
                  icon: const Icon(Icons.close, size: 20),
                )
              : null,
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }

  String _resultsLabel(
    AsyncValue<List<PantryItem>> itemsAsync,
    List<PantryItem> filteredItems,
    PantryFilterState filters,
  ) {
    return itemsAsync.maybeWhen(
      data: (items) {
        if (filters.hasActiveFilters || filters.selectedLocation != null) {
          return '${filteredItems.length} of ${items.length} items';
        }
        return '${items.length} items in your pantry';
      },
      orElse: () => 'Loading items...',
    );
  }
}
