import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/pantry_scope.dart';
import '../providers/active_pantry_scope_provider.dart';
import '../providers/pantry_providers.dart';
import '../utils/pantry_item_actions.dart';
import '../widgets/expiry_status_indicator.dart';
import '../widgets/pantry_active_filter_chips.dart';
import '../widgets/pantry_empty_state.dart';
import '../widgets/pantry_items_sliver.dart';
import '../widgets/pantry_location_selector.dart';
import '../widgets/pantry_search_and_filter_bar.dart';
import '../widgets/pantry_view_mode_toggle.dart';

/// Full matching pantry list. Uses the same Firestore stream as the dashboard.
class PantryItemsScreen extends ConsumerStatefulWidget {
  const PantryItemsScreen({super.key});

  @override
  ConsumerState<PantryItemsScreen> createState() => _PantryItemsScreenState();
}

class _PantryItemsScreenState extends ConsumerState<PantryItemsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // Seed from shared filter state so dashboard search/location survive push.
    _searchController = TextEditingController(
      text: ref.read(pantryFilterProvider).searchQuery,
    );
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _syncSearchController(String query) {
    if (_searchController.text == query) return;
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(pantryFilterProvider.notifier).setSearchQuery('');
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.pantry);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(pantryItemsProvider);
    final filteredItems = ref.watch(filteredPantryItemsProvider);
    final filters = ref.watch(pantryFilterProvider);
    final locationCounts = ref.watch(pantryLocationCountsProvider);
    final viewMode = ref.watch(pantryViewModeProvider);
    final scope = ref.watch(activePantryScopeProvider).asData?.value;

    ref.listen<String>(
      pantryFilterProvider.select((state) => state.searchQuery),
      (previous, next) {
        _syncSearchController(next);
      },
    );

    final colorScheme = Theme.of(context).colorScheme;

    final pageBackground = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: pageBackground,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBack,
        ),
        title: const Text(
          'All Pantry Items',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // Info action moved here from the count toolbar under the chips.
        // AppBar keeps the title in place and centers this action with it.
        actionsPadding: const EdgeInsets.only(right: 4),
        actions: const [ExpiryStatusLegendButton()],
      ),
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
              SliverToBoxAdapter(
                child: PantrySearchAndFilterBar(
                  controller: _searchController,
                  filters: filters,
                  onChanged: (value) {
                    ref
                        .read(pantryFilterProvider.notifier)
                        .setSearchQuery(value);
                  },
                  onClearSearch: _clearSearch,
                ),
              ),
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
                child: PantryActiveFilterChips(onSearchCleared: _clearSearch),
              ),
              // Count label removed. Only the view toggle remains, on the right.
              const SliverToBoxAdapter(child: _AllItemsToolbar()),
              if (scope != null)
                SliverToBoxAdapter(child: _PantryScopeLine(scope: scope)),
              ..._listSlivers(itemsAsync, filteredItems, viewMode),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _listSlivers(
    AsyncValue<List<PantryItem>> itemsAsync,
    List<PantryItem> filteredItems,
    PantryViewMode viewMode,
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: PantryEmptyState(
                type: PantryEmptyStateType.noResults,
                onPrimaryAction: () {
                  _clearSearch();
                  ref.read(pantryFilterProvider.notifier).clearFilters();
                },
              ),
            ),
          ];
        }

        return [PantryItemsSliver(items: filteredItems, viewMode: viewMode)];
      },
    );
  }
}

class _PantryScopeLine extends StatelessWidget {
  const _PantryScopeLine({required this.scope});

  final PantryScope scope;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        scope.headerLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Right-aligned card/list toggle. The item-count label and info action
/// that used to share this row have been removed from this section.
class _AllItemsToolbar extends StatelessWidget {
  const _AllItemsToolbar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 12, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: PantryViewModeToggle(),
      ),
    );
  }
}
