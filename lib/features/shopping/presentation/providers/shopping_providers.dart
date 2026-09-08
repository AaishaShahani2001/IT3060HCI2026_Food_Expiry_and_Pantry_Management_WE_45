import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_shopping_repository.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return MockShoppingRepository();
});

class ShoppingFilterState {
  const ShoppingFilterState({
    this.searchQuery = '',
    this.priority,
    this.showCompleted = true,
  });

  final String searchQuery;
  final ShoppingItemPriority? priority;
  final bool showCompleted;

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty || priority != null || !showCompleted;

  ShoppingFilterState copyWith({
    String? searchQuery,
    ShoppingItemPriority? priority,
    bool? showCompleted,
    bool clearPriority = false,
  }) {
    return ShoppingFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      priority: clearPriority ? null : (priority ?? this.priority),
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }
}

class ShoppingFilterNotifier extends Notifier<ShoppingFilterState> {
  @override
  ShoppingFilterState build() => const ShoppingFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setPriority(ShoppingItemPriority? priority) {
    state = state.copyWith(priority: priority, clearPriority: priority == null);
  }

  void setShowCompleted(bool value) {
    state = state.copyWith(showCompleted: value);
  }

  void clearFilters() {
    state = const ShoppingFilterState();
  }
}

final shoppingFilterProvider =
    NotifierProvider<ShoppingFilterNotifier, ShoppingFilterState>(
      ShoppingFilterNotifier.new,
    );

class ShoppingItemsNotifier extends AsyncNotifier<List<ShoppingItem>> {
  @override
  Future<List<ShoppingItem>> build() async {
    return ref.read(shoppingRepositoryProvider).fetchItems();
  }

  Future<void> refreshItems() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => ref.read(shoppingRepositoryProvider).fetchItems(),
    );
  }

  Future<void> addItem(ShoppingItem item) async {
    final repository = ref.read(shoppingRepositoryProvider);

    final createdItem = await repository.addItem(item);

    final currentItems = state.asData?.value ?? [];

    state = AsyncData([createdItem, ...currentItems]);
  }

  Future<void> updateItem(ShoppingItem item) async {
    final repository = ref.read(shoppingRepositoryProvider);

    final updatedItem = await repository.updateItem(item);

    final currentItems = state.asData?.value ?? [];

    state = AsyncData(
      currentItems
          .map((entry) => entry.id == updatedItem.id ? updatedItem : entry)
          .toList(),
    );
  }

  Future<void> deleteItem(String id) async {
    final repository = ref.read(shoppingRepositoryProvider);

    await repository.deleteItem(id);

    final currentItems = state.asData?.value ?? [];

    state = AsyncData(currentItems.where((item) => item.id != id).toList());
  }

  Future<void> toggleCompleted(String id) async {
    final currentItems = state.asData?.value;

    if (currentItems == null) return;

    final index = currentItems.indexWhere((item) => item.id == id);

    if (index == -1) return;

    final currentItem = currentItems[index];

    final updatedItem = currentItem.copyWith(
      isCompleted: !currentItem.isCompleted,
      updatedAt: DateTime.now(),
    );

    final optimisticItems = [...currentItems];
    optimisticItems[index] = updatedItem;

    state = AsyncData(optimisticItems);

    try {
      final savedItem = await ref
          .read(shoppingRepositoryProvider)
          .updateItem(updatedItem);

      final latestItems = state.asData?.value ?? optimisticItems;

      state = AsyncData(
        latestItems
            .map((item) => item.id == savedItem.id ? savedItem : item)
            .toList(),
      );
    } catch (_) {
      state = AsyncData(currentItems);
      rethrow;
    }
  }
}

final shoppingItemsProvider =
    AsyncNotifierProvider<ShoppingItemsNotifier, List<ShoppingItem>>(
      ShoppingItemsNotifier.new,
    );

final filteredShoppingItemsProvider = Provider<List<ShoppingItem>>((ref) {
  final itemsAsync = ref.watch(shoppingItemsProvider);
  final filters = ref.watch(shoppingFilterProvider);

  return itemsAsync.maybeWhen(
    data: (items) => _applyFilters(items, filters),
    orElse: () => const [],
  );
});

final shoppingSummaryProvider =
    Provider<({int total, int completed, int pending})>((ref) {
      final itemsAsync = ref.watch(shoppingItemsProvider);

      return itemsAsync.maybeWhen(
        data: (items) {
          final completed = items.where((item) => item.isCompleted).length;

          return (
            total: items.length,
            completed: completed,
            pending: items.length - completed,
          );
        },
        orElse: () => (total: 0, completed: 0, pending: 0),
      );
    });

List<ShoppingItem> _applyFilters(
  List<ShoppingItem> items,
  ShoppingFilterState filters,
) {
  return items.where((item) {
    final matchesSearch =
        filters.searchQuery.isEmpty ||
        item.name.toLowerCase().contains(filters.searchQuery.toLowerCase());

    final matchesPriority =
        filters.priority == null || item.priority == filters.priority;

    final matchesCompleted = filters.showCompleted || !item.isCompleted;

    return matchesSearch && matchesPriority && matchesCompleted;
  }).toList();
}
