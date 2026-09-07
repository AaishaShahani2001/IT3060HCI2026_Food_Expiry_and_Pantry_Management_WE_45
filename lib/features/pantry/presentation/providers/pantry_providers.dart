import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_pantry_repository.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return MockPantryRepository();
});

class PantryFilterState {
  const PantryFilterState({
    this.searchQuery = '',
    this.selectedLocation,
    this.selectedCategory,
    this.stockLevel = StockLevelFilter.all,
  });

  final String searchQuery;
  final PantryLocation? selectedLocation;
  final PantryCategory? selectedCategory;
  final StockLevelFilter stockLevel;

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedLocation != null ||
      selectedCategory != null ||
      stockLevel != StockLevelFilter.all;

  PantryFilterState copyWith({
    String? searchQuery,
    PantryLocation? selectedLocation,
    PantryCategory? selectedCategory,
    StockLevelFilter? stockLevel,
    bool clearLocation = false,
    bool clearCategory = false,
  }) {
    return PantryFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLocation: clearLocation
          ? null
          : (selectedLocation ?? this.selectedLocation),
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      stockLevel: stockLevel ?? this.stockLevel,
    );
  }
}

class PantryFilterNotifier extends Notifier<PantryFilterState> {
  @override
  PantryFilterState build() => const PantryFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setLocation(PantryLocation? location) {
    state = state.copyWith(
      selectedLocation: location,
      clearLocation: location == null,
    );
  }

  void setCategory(PantryCategory? category) {
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
    );
  }

  void setStockLevel(StockLevelFilter stockLevel) {
    state = state.copyWith(stockLevel: stockLevel);
  }

  void clearFilters() {
    state = const PantryFilterState();
  }
}

final pantryFilterProvider =
    NotifierProvider<PantryFilterNotifier, PantryFilterState>(
      PantryFilterNotifier.new,
    );

class PantryItemsNotifier extends AsyncNotifier<List<PantryItem>> {
  @override
  Future<List<PantryItem>> build() async {
    return ref.read(pantryRepositoryProvider).fetchItems();
  }

  Future<void> refreshItems() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(pantryRepositoryProvider).fetchItems(),
    );
  }

  Future<void> addItem(PantryItem item) async {
    final repository = ref.read(pantryRepositoryProvider);
    final createdItem = await repository.addItem(item);
    final currentItems = state.asData?.value ?? [];
    state = AsyncData([createdItem, ...currentItems]);
  }

  Future<void> updateItem(PantryItem item) async {
    final repository = ref.read(pantryRepositoryProvider);
    final updatedItem = await repository.updateItem(item);
    final currentItems = state.asData?.value ?? [];
    state = AsyncData(
      currentItems
          .map((entry) => entry.id == updatedItem.id ? updatedItem : entry)
          .toList(),
    );
  }

  Future<void> deleteItem(String id) async {
    final repository = ref.read(pantryRepositoryProvider);
    await repository.deleteItem(id);
    final currentItems = state.asData?.value ?? [];
    state = AsyncData(currentItems.where((item) => item.id != id).toList());
  }

  /// Instantly adjusts quantity via +/- controls without opening the edit form.
  Future<void> adjustQuantity(String id, double delta) async {
    final currentItems = state.asData?.value;
    if (currentItems == null) return;

    final index = currentItems.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final current = currentItems[index];
    final nextQuantity = (current.quantity + delta).clamp(0.0, double.infinity);
    if (nextQuantity == current.quantity) return;

    final updatedItem = current.withAdjustedQuantity(delta);

    // Optimistic UI update for immediate feedback.
    final optimistic = [...currentItems];
    optimistic[index] = updatedItem;
    state = AsyncData(optimistic);

    try {
      final saved = await ref
          .read(pantryRepositoryProvider)
          .updateItem(updatedItem);
      final latest = state.asData?.value ?? optimistic;
      state = AsyncData(
        latest.map((entry) => entry.id == saved.id ? saved : entry).toList(),
      );
    } catch (_) {
      // Roll back if persistence fails.
      state = AsyncData(currentItems);
      rethrow;
    }
  }
}

final pantryItemsProvider =
    AsyncNotifierProvider<PantryItemsNotifier, List<PantryItem>>(
      PantryItemsNotifier.new,
    );

final filteredPantryItemsProvider = Provider<List<PantryItem>>((ref) {
  final itemsAsync = ref.watch(pantryItemsProvider);
  final filters = ref.watch(pantryFilterProvider);

  return itemsAsync.maybeWhen(
    data: (items) => _applyFilters(items, filters),
    orElse: () => const [],
  );
});

final pantrySummaryProvider = Provider<({int total, int lowStock})>((ref) {
  final itemsAsync = ref.watch(pantryItemsProvider);
  return itemsAsync.maybeWhen(
    data: (items) {
      final lowStockCount = items.where((item) => item.isLowStock).length;
      return (total: items.length, lowStock: lowStockCount);
    },
    orElse: () => (total: 0, lowStock: 0),
  );
});

/// Item counts per location tab, including the "All" total (null key).
final pantryLocationCountsProvider = Provider<Map<PantryLocation?, int>>((ref) {
  final itemsAsync = ref.watch(pantryItemsProvider);
  return itemsAsync.maybeWhen(
    data: (items) {
      final counts = <PantryLocation?, int>{
        null: items.length,
        PantryLocation.refrigerator: 0,
        PantryLocation.freezer: 0,
        PantryLocation.pantry: 0,
      };
      for (final item in items) {
        counts[item.location] = (counts[item.location] ?? 0) + 1;
      }
      return counts;
    },
    orElse: () => const {
      null: 0,
      PantryLocation.refrigerator: 0,
      PantryLocation.freezer: 0,
      PantryLocation.pantry: 0,
    },
  );
});

List<PantryItem> _applyFilters(
  List<PantryItem> items,
  PantryFilterState filters,
) {
  return items.where((item) {
    final matchesSearch =
        filters.searchQuery.isEmpty ||
        item.name.toLowerCase().contains(filters.searchQuery.toLowerCase());

    final matchesLocation =
        filters.selectedLocation == null ||
        item.location == filters.selectedLocation;

    final matchesCategory =
        filters.selectedCategory == null ||
        item.category == filters.selectedCategory;

    final matchesStock = switch (filters.stockLevel) {
      StockLevelFilter.all => true,
      StockLevelFilter.inStock => !item.isLowStock,
      StockLevelFilter.lowStock => item.isLowStock,
    };

    return matchesSearch && matchesLocation && matchesCategory && matchesStock;
  }).toList();
}
