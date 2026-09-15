import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';
import '../utils/pantry_item_actions.dart';
import '../widgets/expiry_status_indicator.dart';
import '../widgets/pantry_empty_state.dart';
import '../widgets/pantry_filter_bottom_sheet.dart';
import '../widgets/pantry_items_sliver.dart';
import '../widgets/pantry_location_selector.dart';
import '../widgets/pantry_recent_items_header.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(pantryFilterProvider).searchQuery;
    _searchController.text = initialQuery;
    _isSearchVisible = initialQuery.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _syncSearchController(String query) {
    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    final shouldShow = query.isNotEmpty;
    if (shouldShow != _isSearchVisible && query.isNotEmpty) {
      setState(() => _isSearchVisible = true);
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
    final previewItems = ref.watch(pantryPreviewItemsProvider);
    final filters = ref.watch(pantryFilterProvider);
    final locationCounts = ref.watch(pantryLocationCountsProvider);

    ref.listen<String>(
      pantryFilterProvider.select((state) => state.searchQuery),
      (previous, next) {
        _syncSearchController(next);
      },
    );

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openPantryAddItem(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colorScheme.primary,
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
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
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                          ),
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                ),
              ),
              ..._previewSlivers(itemsAsync, filteredItems, previewItems),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _previewSlivers(
    AsyncValue<List<PantryItem>> itemsAsync,
    List<PantryItem> filteredItems,
    List<PantryItem> previewItems,
  ) {
    return itemsAsync.when(
      loading: () => const [
        SliverFillRemaining(hasScrollBody: false, child: PantryLoadingState()),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PantryEmptyState(
            type: PantryEmptyStateType.error,
            message: mapPantryLoadError(error),
            onRetry: () {
              ref.read(pantryItemsProvider.notifier).refreshItems();
            },
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: PantryEmptyState(
                type: PantryEmptyStateType.noItems,
                onPrimaryAction: () => openPantryAddItem(context),
              ),
            ),
          ];
        }

        if (filteredItems.isEmpty) {
          return [
            const SliverToBoxAdapter(
              child: PantryRecentItemsHeader(matchingCount: 0),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: PantryEmptyState(
                type: PantryEmptyStateType.noResults,
                onPrimaryAction: () {
                  _searchController.clear();
                  setState(() => _isSearchVisible = false);
                  ref.read(pantryFilterProvider.notifier).clearFilters();
                },
              ),
            ),
          ];
        }

        return [
          SliverToBoxAdapter(
            child: PantryRecentItemsHeader(matchingCount: filteredItems.length),
          ),
          PantryItemsSliver(
            // Derive a five-item dashboard preview without modifying the
            // complete Firestore-backed list used by View All.
            items: previewItems,
            viewMode: PantryViewMode.cards,
          ),
        ];
      },
    );
  }

  Widget _buildHeader(BuildContext context, PantryFilterState filters) {
    final colorScheme = Theme.of(context).colorScheme;
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
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and organize your food items',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
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
                  ? colorScheme.primary
                  : colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
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
          prefixIcon: Icon(Icons.search, color: colorScheme.primary),
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
          fillColor: colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
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
