import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/pantry_item.dart';
import '../../domain/utils/pantry_list_query.dart';
import '../providers/pantry_providers.dart';

class PantryFilterBottomSheet extends ConsumerWidget {
  const PantryFilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const PantryFilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(pantryFilterProvider);
    final filterNotifier = ref.read(pantryFilterProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    // Cap height and shrink-wrap so chips can scroll instead of overflowing
    // the bottom of the sheet on short phones.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: filters.hasActiveFilters
                      ? () {
                          filterNotifier.clearFilters();
                        }
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All categories'),
                  selected: filters.selectedCategory == null,
                  onSelected: (_) => filterNotifier.setCategory(null),
                  selectedColor: colorScheme.secondaryContainer,
                  checkmarkColor: colorScheme.primary,
                  labelStyle: TextStyle(color: colorScheme.onSurface),
                ),
                ...PantryCategory.values.map(
                  (category) => FilterChip(
                    avatar: Icon(category.icon, size: 16),
                    label: Text(category.label),
                    selected: filters.selectedCategory == category,
                    onSelected: (_) => filterNotifier.setCategory(category),
                    selectedColor: colorScheme.secondaryContainer,
                    checkmarkColor: colorScheme.primary,
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All locations'),
                  selected: filters.selectedLocation == null,
                  onSelected: (_) => filterNotifier.setLocation(null),
                  selectedColor: colorScheme.secondaryContainer,
                  checkmarkColor: colorScheme.primary,
                  labelStyle: TextStyle(color: colorScheme.onSurface),
                ),
                ...PantryLocation.values.map(
                  (location) => FilterChip(
                    avatar: Icon(location.icon, size: 16),
                    label: Text(location.label),
                    selected: filters.selectedLocation == location,
                    onSelected: (_) => filterNotifier.setLocation(location),
                    selectedColor: colorScheme.secondaryContainer,
                    checkmarkColor: colorScheme.primary,
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Stock level',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StockLevelFilter.values
                  .map(
                    (level) => FilterChip(
                      label: Text(level.label),
                      selected: filters.stockLevel == level,
                      onSelected: (_) => filterNotifier.setStockLevel(level),
                      selectedColor: colorScheme.secondaryContainer,
                      checkmarkColor: colorScheme.primary,
                      labelStyle: TextStyle(color: colorScheme.onSurface),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Sort by',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PantrySortOption.values
                  .map(
                    (option) => FilterChip(
                      label: Text(option.label),
                      selected: filters.sortOption == option,
                      onSelected: (_) => filterNotifier.setSortOption(option),
                      selectedColor: colorScheme.secondaryContainer,
                      checkmarkColor: colorScheme.primary,
                      labelStyle: TextStyle(color: colorScheme.onSurface),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
