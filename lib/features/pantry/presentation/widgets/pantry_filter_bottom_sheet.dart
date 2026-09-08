import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';

class PantryFilterBottomSheet extends ConsumerWidget {
  const PantryFilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
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
                  ),
                ),
                TextButton(
                  onPressed: filters.hasActiveFilters
                      ? () {
                          filterNotifier.clearFilters();
                        }
                      : null,
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
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
                  selectedColor: AppColors.softGreen,
                ),
                ...PantryCategory.values.map(
                  (category) => FilterChip(
                    avatar: Icon(category.icon, size: 16),
                    label: Text(category.label),
                    selected: filters.selectedCategory == category,
                    onSelected: (_) => filterNotifier.setCategory(category),
                    selectedColor: AppColors.softGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
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
                  selectedColor: AppColors.softGreen,
                ),
                ...PantryLocation.values.map(
                  (location) => FilterChip(
                    avatar: Icon(location.icon, size: 16),
                    label: Text(location.label),
                    selected: filters.selectedLocation == location,
                    onSelected: (_) => filterNotifier.setLocation(location),
                    selectedColor: AppColors.softGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Stock level',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 8),
            ...StockLevelFilter.values.map(
              (level) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilterChip(
                  label: Text(level.label),
                  selected: filters.stockLevel == level,
                  onSelected: (_) => filterNotifier.setStockLevel(level),
                  selectedColor: AppColors.softGreen,
                  showCheckmark: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
