import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../shopping_list/presentation/widgets/shopping_guided_help.dart';
import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/active_pantry_scope_provider.dart';
import '../providers/pantry_guided_help_provider.dart';
import '../providers/pantry_providers.dart';
import '../utils/pantry_item_actions.dart';
import '../widgets/pantry_empty_state.dart';
import '../widgets/pantry_filter_bottom_sheet.dart';
import '../widgets/pantry_items_sliver.dart';
import '../widgets/pantry_location_selector.dart';
import '../widgets/pantry_recent_items_header.dart';

enum _PantryFirstItemHelpAction { notNow, continueGuide }

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _scopeHelpKey = GlobalKey();
  final GlobalKey _locationsHelpKey = GlobalKey();
  final GlobalKey _viewAllHelpKey = GlobalKey();
  final GlobalKey _itemCardHelpKey = GlobalKey();
  final GlobalKey _quantityHelpKey = GlobalKey();
  final GlobalKey _actionsHelpKey = GlobalKey();
  final GlobalKey _addItemHelpKey = GlobalKey();
  String? _scheduledContinuationIdentity;
  bool _continuationDialogVisible = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(pantryFilterProvider).searchQuery;
    _searchController.text = initialQuery;
    _isSearchVisible = initialQuery.isNotEmpty;
    ref.listenManual<PantryFirstItemHelpState>(pantryFirstItemHelpProvider, (
      _,
      next,
    ) {
      if (_scheduledContinuationIdentity != next.identity?.key) {
        _scheduledContinuationIdentity = null;
      }
      _observePantryItems(ref.read(pantryItemsProvider));
    }, fireImmediately: true);
    ref.listenManual<AsyncValue<List<PantryItem>>>(
      pantryItemsProvider,
      (_, next) => _observePantryItems(next),
      fireImmediately: true,
    );
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

  Future<void> _showHelp() async {
    _searchFocusNode.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showShoppingGuidedHelp(context, [
      ShoppingHelpStep(
        targetKey: _scopeHelpKey,
        title: 'Personal or Shared Pantry',
        description:
            'This header shows whether you are viewing your personal pantry or a pantry shared with household members.',
      ),
      ShoppingHelpStep(
        targetKey: _locationsHelpKey,
        title: 'Filter by Location',
        description:
            'Use All, Refrigerator, Freezer, or Pantry to focus on items stored in one place.',
      ),
      ShoppingHelpStep(
        targetKey: _viewAllHelpKey,
        title: 'View All Pantry Items',
        description: 'Open the complete pantry list from here.',
      ),
      ..._itemHelpSteps(),
      ShoppingHelpStep(
        targetKey: _addItemHelpKey,
        title: 'Add Pantry Items',
        description: 'Add a new item to your pantry here.',
      ),
    ]);
  }

  List<ShoppingHelpStep> _itemHelpSteps() => [
    ShoppingHelpStep(
      targetKey: _itemCardHelpKey,
      title: 'Pantry Item Details',
      description:
          'Each card shows quantity, category, location, and stock. Expiry indicators mean Fresh, Expiring soon, Expired, or Expiry date unknown.',
    ),
    ShoppingHelpStep(
      targetKey: _quantityHelpKey,
      title: 'Update Quantity',
      description:
          'Use minus and plus to update the amount remaining in your pantry.',
    ),
    ShoppingHelpStep(
      targetKey: _actionsHelpKey,
      title: 'Item Actions',
      description:
          'Open the three-dot menu to edit, mark as used up, or delete an item.',
    ),
  ];

  void _observePantryItems(AsyncValue<List<PantryItem>> next) {
    final items = next.asData?.value;
    if (items == null || items.isEmpty || _continuationDialogVisible) return;
    final helpState = ref.read(pantryFirstItemHelpProvider);
    final identity = helpState.identity;
    if (!helpState.shouldPrompt || identity == null) return;
    if (_scheduledContinuationIdentity == identity.key) return;
    _scheduledContinuationIdentity = identity.key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showFirstItemContinuationPrompt(identity);
    });
  }

  Future<void> _showFirstItemContinuationPrompt(
    PantryFirstItemHelpIdentity expectedIdentity,
  ) async {
    if (!await _waitForCurrentRouteTransition()) {
      if (_scheduledContinuationIdentity == expectedIdentity.key) {
        _scheduledContinuationIdentity = null;
      }
      return;
    }
    final items = ref.read(pantryItemsProvider).asData?.value;
    final helpState = ref.read(pantryFirstItemHelpProvider);
    if (items == null ||
        items.isEmpty ||
        helpState.identity != expectedIdentity ||
        !helpState.shouldPrompt ||
        _continuationDialogVisible) {
      if (_scheduledContinuationIdentity == expectedIdentity.key) {
        _scheduledContinuationIdentity = null;
      }
      return;
    }
    final claimed = ref
        .read(pantryFirstItemHelpProvider.notifier)
        .claimPrompt(expectedIdentity);
    if (!claimed) {
      _scheduledContinuationIdentity = null;
      return;
    }
    _continuationDialogVisible = true;
    final action = await showDialog<_PantryFirstItemHelpAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _buildFirstItemContinuationDialog(dialogContext),
    );
    _continuationDialogVisible = false;
    _scheduledContinuationIdentity = null;
    if (action != _PantryFirstItemHelpAction.continueGuide || !mounted) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showShoppingGuidedHelp(context, _itemHelpSteps());
  }

  Future<bool> _waitForCurrentRouteTransition() async {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    if (route?.isCurrent == false) return false;
    final animations = [route?.animation, route?.secondaryAnimation];
    for (final animation in animations) {
      if (animation == null ||
          (animation.status != AnimationStatus.forward &&
              animation.status != AnimationStatus.reverse)) {
        continue;
      }
      final completer = Completer<void>();
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.forward ||
            status == AnimationStatus.reverse) {
          return;
        }
        animation.removeStatusListener(listener);
        if (!completer.isCompleted) completer.complete();
      }

      animation.addStatusListener(listener);
      await completer.future;
      if (!mounted) return false;
    }
    return mounted && route?.isCurrent != false;
  }

  Widget _buildFirstItemContinuationDialog(BuildContext dialogContext) {
    final colorScheme = Theme.of(dialogContext).colorScheme;
    return AlertDialog(
      key: const ValueKey('pantry-first-item-help-prompt'),
      backgroundColor: colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outline),
      ),
      icon: Icon(Icons.inventory_2_outlined, color: colorScheme.primary),
      title: const Text(
        'Your first pantry item is ready!',
        textAlign: TextAlign.center,
      ),
      content: const SingleChildScrollView(
        child: Text(
          'Want a quick tour of the item controls?',
          textAlign: TextAlign.center,
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(_PantryFirstItemHelpAction.notNow),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(_PantryFirstItemHelpAction.continueGuide),
          child: const Text('Continue guide'),
        ),
      ],
    );
  }

  Future<void> _openAddItem() async {
    final items = ref.read(pantryItemsProvider).asData?.value;
    if (items != null && items.isEmpty) {
      ref.read(pantryFirstItemHelpProvider.notifier).recordEmptyPantrySeen();
    }
    await openPantryAddItem(context);
    if (!mounted) return;
    _observePantryItems(ref.read(pantryItemsProvider));
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        key: _addItemHelpKey,
        onPressed: _openAddItem,
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
              // No extra gap under the chips: the item-count row that used to
              // sit here has been removed.
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _locationsHelpKey,
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
              // Item-count text ("N items in your pantry") is not shown here.
              // The expiry info action now lives in the header, after Filter.
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
                onPrimaryAction: _openAddItem,
              ),
            ),
          ];
        }

        if (filteredItems.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: PantryRecentItemsHeader(
                matchingCount: 0,
                viewAllHelpKey: _viewAllHelpKey,
              ),
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
            child: PantryRecentItemsHeader(
              matchingCount: filteredItems.length,
              viewAllHelpKey: _viewAllHelpKey,
            ),
          ),
          PantryItemsSliver(
            // Derive a six-item dashboard preview without modifying the
            // complete Firestore-backed list used by View All.
            items: previewItems,
            viewMode: PantryViewMode.cards,
            firstItemHelpTargets: PantryItemHelpTargets(
              cardKey: _itemCardHelpKey,
              quantityKey: _quantityHelpKey,
              actionsKey: _actionsHelpKey,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildHeader(BuildContext context, PantryFilterState filters) {
    final colorScheme = Theme.of(context).colorScheme;
    final scope = ref.watch(activePantryScopeProvider).asData?.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              key: _scopeHelpKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scope?.headerLabel ?? 'My Pantry',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          IconButton(
            onPressed: _showHelp,
            tooltip: 'Pantry help',
            icon: const Icon(Icons.info_outline_rounded),
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
}
