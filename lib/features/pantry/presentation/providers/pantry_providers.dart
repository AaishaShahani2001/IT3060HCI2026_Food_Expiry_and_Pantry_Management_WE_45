import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/utils/pantry_duplicate_lookup.dart';

final pantryFirestoreServiceProvider = Provider<PantryFirestoreService>((ref) {
  return PantryFirestoreService();
});

/// Item IDs with a quantity or Mark Consumed write in progress.
class PantryBusyItemIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void start(String id) => state = {...state, id};

  void stop(String id) {
    state = {...state}..remove(id);
  }
}

final pantryBusyItemIdsProvider =
    NotifierProvider<PantryBusyItemIdsNotifier, Set<String>>(
      PantryBusyItemIdsNotifier.new,
    );

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

class PantryItemsNotifier extends StreamNotifier<List<PantryItem>> {
  @override
  Stream<List<PantryItem>> build() {
    final service = ref.watch(pantryFirestoreServiceProvider);
    return _watchPantryForSignedInUser(service);
  }

  Future<void> refreshItems() async {
    ref.invalidateSelf();
  }

  Future<void> addItem(PantryItem item) async {
    await ref.read(pantryFirestoreServiceProvider).addItem(item);
  }

  /// Returns the first current pantry item whose name matches [name]
  /// (trimmed, case-insensitive). Pass [excludeItemId] when editing so the
  /// item being saved is not treated as its own duplicate.
  ///
  /// Uses the in-memory Firestore stream so this can later be replaced with
  /// a Firestore query.
  PantryItem? findDuplicateByName(String name, {String? excludeItemId}) {
    return lookupDuplicatePantryItemByName(
      state.asData?.value ?? const <PantryItem>[],
      name,
      excludeItemId: excludeItemId,
    );
  }

  Future<void> updateItem(PantryItem item) async {
    final connection = _requireFirestoreConnection(item);
    await ref
        .read(pantryFirestoreServiceProvider)
        .updatePantryItem(
          userId: connection.userId,
          itemId: connection.itemId,
          item: item,
        );
  }

  Future<void> deleteItem(PantryItem item) async {
    final connection = _requireFirestoreConnection(item);
    await ref
        .read(pantryFirestoreServiceProvider)
        .deletePantryItem(userId: connection.userId, itemId: connection.itemId);
  }

  /// Edit/Delete/quantity need a signed-in user and a real Firestore document ID.
  ({String userId, String itemId}) _requireFirestoreConnection(
    PantryItem item, {
    bool forQuantityUpdate = false,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw PantryFirestoreException(
        forQuantityUpdate
            ? 'Please log in before updating an item.'
            : 'Please log in before continuing.',
      );
    }

    final firestoreId = item.firestoreId;
    if (firestoreId == null || firestoreId.trim().isEmpty) {
      throw const PantryFirestoreException(
        'This item is local-only and is not connected to Firestore yet.',
      );
    }

    return (userId: user.uid, itemId: firestoreId);
  }

  /// +/- controls. Firestore write first; the stream updates the UI.
  Future<void> adjustQuantity(String id, double delta) async {
    final currentItems = state.asData?.value;
    if (currentItems == null) return;

    final index = currentItems.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final current = currentItems[index];
    if (delta < 0 && current.quantity <= 0) return;

    final busy = ref.read(pantryBusyItemIdsProvider);
    if (busy.contains(id)) return;

    final connection = _requireFirestoreConnection(
      current,
      forQuantityUpdate: true,
    );
    final busyNotifier = ref.read(pantryBusyItemIdsProvider.notifier);
    busyNotifier.start(id);

    try {
      await ref
          .read(pantryFirestoreServiceProvider)
          .changeItemQuantity(
            userId: connection.userId,
            itemId: connection.itemId,
            change: delta,
          );
    } finally {
      busyNotifier.stop(id);
    }
  }

  /// Mark Consumed write. Returns the remaining quantity from Firestore.
  Future<double> markConsumed({
    required PantryItem item,
    required double consumedQuantity,
  }) async {
    if (consumedQuantity <= 0) {
      throw const PantryFirestoreException('Enter a quantity greater than 0.');
    }

    final currentItems = state.asData?.value;
    PantryItem current = item;
    if (currentItems != null) {
      for (final entry in currentItems) {
        if (entry.id == item.id ||
            (item.firestoreId != null &&
                entry.firestoreId == item.firestoreId)) {
          current = entry;
          break;
        }
      }
    }

    final busy = ref.read(pantryBusyItemIdsProvider);
    if (busy.contains(current.id)) {
      throw const PantryFirestoreException(
        'Something went wrong. Please try again.',
      );
    }

    final connection = _requireFirestoreConnection(
      current,
      forQuantityUpdate: true,
    );
    final busyNotifier = ref.read(pantryBusyItemIdsProvider.notifier);
    busyNotifier.start(current.id);

    try {
      return await ref
          .read(pantryFirestoreServiceProvider)
          .markItemConsumed(
            userId: connection.userId,
            itemId: connection.itemId,
            consumedQuantity: consumedQuantity,
          );
    } finally {
      busyNotifier.stop(current.id);
    }
  }
}

final pantryItemsProvider =
    StreamNotifierProvider<PantryItemsNotifier, List<PantryItem>>(
      PantryItemsNotifier.new,
    );

/// Switches the pantry stream when the signed-in user changes.
Stream<List<PantryItem>> _watchPantryForSignedInUser(
  PantryFirestoreService service,
) {
  late final StreamController<List<PantryItem>> controller;
  StreamSubscription<User?>? authSub;
  StreamSubscription<List<PantryItem>>? pantrySub;

  controller = StreamController<List<PantryItem>>(
    onListen: () {
      authSub = FirebaseAuth.instance.authStateChanges().listen(
        (user) async {
          await pantrySub?.cancel();
          pantrySub = null;
          if (user == null) {
            if (!controller.isClosed) {
              controller.add(const <PantryItem>[]);
            }
            return;
          }
          pantrySub = service
              .watchPantryItems(userId: user.uid)
              .listen(
                (items) {
                  if (!controller.isClosed) controller.add(items);
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!controller.isClosed) {
                    controller.addError(error, stackTrace);
                  }
                },
              );
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );
    },
    onCancel: () async {
      await pantrySub?.cancel();
      await authSub?.cancel();
    },
  );

  return controller.stream;
}

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
