import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/pantry_item.dart';
import '../../domain/utils/pantry_list_query.dart';
import '../providers/pantry_providers.dart';

/// Removable chips for the shared search/location/category/stock filters.
class PantryActiveFilterChips extends ConsumerWidget {
  const PantryActiveFilterChips({this.onSearchCleared, super.key});

  /// Called when the search chip is removed so TextEditingControllers stay in
  /// sync with [pantryFilterProvider].
  final VoidCallback? onSearchCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(pantryFilterProvider);
    if (!filters.hasActiveFilters && !filters.hasCustomSort) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(pantryFilterProvider.notifier);
    final chips = <Widget>[
      if (filters.searchQuery.trim().isNotEmpty)
        _FilterChip(
          label: 'Search: ${filters.searchQuery.trim()}',
          onDeleted: () {
            notifier.setSearchQuery('');
            onSearchCleared?.call();
          },
        ),
      if (filters.selectedLocation != null)
        _FilterChip(
          label: filters.selectedLocation!.label,
          onDeleted: () => notifier.setLocation(null),
        ),
      if (filters.selectedCategory != null)
        _FilterChip(
          label: filters.selectedCategory!.label,
          onDeleted: () => notifier.setCategory(null),
        ),
      if (filters.stockLevel != StockLevelFilter.all)
        _FilterChip(
          label: filters.stockLevel.label,
          onDeleted: () => notifier.setStockLevel(StockLevelFilter.all),
        ),
      if (filters.hasCustomSort)
        _FilterChip(
          label: filters.sortOption.label,
          onDeleted: () =>
              notifier.setSortOption(PantrySortOption.recentlyAdded),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          if (filters.hasMultipleActiveFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  notifier.clearFilters();
                  onSearchCleared?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Clear All Filters'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 16),
      tooltip: 'Remove $label',
      backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.65),
      side: BorderSide(color: colorScheme.outline),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
    );
  }
}
