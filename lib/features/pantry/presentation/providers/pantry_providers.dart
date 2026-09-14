import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/models/removed_pantry_item.dart';
import '../../domain/utils/pantry_duplicate_lookup.dart';

const Duration _quantityDebounce = Duration(milliseconds: 550);

final pantryFirestoreServiceProvider = Provider<PantryFirestoreService>((ref) {
  return PantryFirestoreService();
});

/// Item IDs with Used Up or Delete in progress.
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

/// Per-item optimistic quantities while a rapid-tap sequence is in progress.
class PantryPendingQuantitiesNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void setQuantity(String id, double quantity) {
    state = {...state, id: quantity};
  }

  void remove(String id) {
    if (!state.containsKey(id)) return;
    final next = {...state}..remove(id);
    state = next;
  }
}

final pantryPendingQuantitiesProvider =
    NotifierProvider<PantryPendingQuantitiesNotifier, Map<String, double>>(
      PantryPendingQuantitiesNotifier.new,
    );

enum PantryQuantityChangeResult { applied, wouldGoNegative, ignored }

class PantryQuantityWriteResult {
  const PantryQuantityWriteResult({
    required this.itemId,
    required this.itemName,
    required this.quantityLabel,
    required this.success,
  });

  final String itemId;
  final String itemName;
  final String quantityLabel;
  final bool success;
}

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
  final Map<String, _QuantityEditSession> _quantitySessions = {};

  @override
  Stream<List<PantryItem>> build() {
    ref.onDispose(_disposeQuantitySessions);
    final service = ref.watch(pantryFirestoreServiceProvider);
    return _watchPantryForSignedInUser(service).map((items) {
      Future<void>.microtask(() => _syncPendingQuantitiesWithStream(items));
      return items;
    });
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

  /// Permanently deletes [item]. Busy only for this item.
  Future<void> permanentlyDelete(PantryItem item) async {
    if (ref.read(pantryBusyItemIdsProvider).contains(item.id)) return;

    _cancelQuantitySession(item.id);
    final busyNotifier = ref.read(pantryBusyItemIdsProvider.notifier);
    busyNotifier.start(item.id);
    try {
      await deleteItem(item);
    } on PantryFirestoreException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Pantry permanent delete failed: $error');
      debugPrint('$stackTrace');
      throw PantryFirestoreException(
        'Unable to delete ${item.name}. Please try again.',
      );
    } finally {
      busyNotifier.stop(item.id);
    }
  }

  /// Deletes the Firestore document after snapshotting [item] for Undo.
  Future<RemovedPantryItem?> markAsUsedUp(
    PantryItem item, {
    required int originalIndex,
  }) async {
    if (ref.read(pantryBusyItemIdsProvider).contains(item.id)) return null;

    _cancelQuantitySession(item.id);
    final connection = _requireFirestoreConnection(item);
    final busyNotifier = ref.read(pantryBusyItemIdsProvider.notifier);
    busyNotifier.start(item.id);
    try {
      return await ref
          .read(pantryFirestoreServiceProvider)
          .markAsUsedUp(
            userId: connection.userId,
            item: item,
            originalIndex: originalIndex,
          );
    } on PantryFirestoreException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Pantry Used Up failed: $error');
      debugPrint('$stackTrace');
      throw PantryFirestoreException(
        'Unable to mark ${item.name} as used up. Please try again.',
      );
    } finally {
      busyNotifier.stop(item.id);
    }
  }

  /// Recreates the Used Up Firestore document using its original ID.
  Future<void> restoreUsedUpItem(RemovedPantryItem removedItem) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PantryFirestoreException(kPantrySignInRequiredMessage);
    }

    try {
      await ref
          .read(pantryFirestoreServiceProvider)
          .restoreUsedUpItem(userId: user.uid, removedItem: removedItem);
    } on PantryFirestoreException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Pantry Used Up restore failed: $error');
      debugPrint('$stackTrace');
      throw PantryFirestoreException(
        'Unable to restore ${removedItem.name}. Please try again.',
      );
    }
  }

  ({String userId, String itemId}) _requireFirestoreConnection(
    PantryItem item,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PantryFirestoreException(kPantrySignInRequiredMessage);
    }

    final firestoreId = item.firestoreId;
    if (firestoreId == null || firestoreId.trim().isEmpty) {
      throw const PantryFirestoreException(
        'This item is local-only and is not connected to Firestore yet.',
      );
    }

    return (userId: user.uid, itemId: firestoreId);
  }

  /// Immediate UI quantity change. Persists after a short per-item debounce.
  PantryQuantityChangeResult changeQuantityOptimistically({
    required PantryItem item,
    required double delta,
    void Function(PantryQuantityWriteResult result)? onFlushed,
  }) {
    if (delta == 0) return PantryQuantityChangeResult.applied;

    final id = item.id;
    if (ref.read(pantryBusyItemIdsProvider).contains(id)) {
      return PantryQuantityChangeResult.ignored;
    }

    final displayed =
        ref.read(pantryPendingQuantitiesProvider)[id] ?? item.quantity;
    final next = double.parse((displayed + delta).toStringAsFixed(2));
    if (next < 0) {
      return PantryQuantityChangeResult.wouldGoNegative;
    }

    var session = _quantitySessions[id];
    if (session == null || session.writeCompleted) {
      session = _QuantityEditSession(
        item: item,
        originalQuantity: displayed,
        pendingQuantity: next,
      );
      _quantitySessions[id] = session;
    } else {
      session.pendingQuantity = next;
    }
    final activeSession = session;
    activeSession.onFlushed = onFlushed ?? activeSession.onFlushed;

    ref.read(pantryPendingQuantitiesProvider.notifier).setQuantity(id, next);

    activeSession.debounceTimer?.cancel();
    activeSession.debounceTimer = Timer(_quantityDebounce, () {
      unawaited(_flushQuantity(activeSession));
    });

    return PantryQuantityChangeResult.applied;
  }

  Future<void> undoQuantityChange(String itemId) async {
    final session = _quantitySessions[itemId];
    if (session == null) return;

    session.debounceTimer?.cancel();
    final original = session.originalQuantity;
    session.pendingQuantity = original;
    ref
        .read(pantryPendingQuantitiesProvider.notifier)
        .setQuantity(itemId, original);

    if (!session.writeCompleted && !session.writeInProgress) {
      ref.read(pantryPendingQuantitiesProvider.notifier).remove(itemId);
      _quantitySessions.remove(itemId);
      return;
    }

    try {
      session.writeInProgress = true;
      final connection = _requireFirestoreConnection(session.item);
      await ref
          .read(pantryFirestoreServiceProvider)
          .updateQuantity(
            userId: connection.userId,
            itemId: connection.itemId,
            quantity: original,
          );
      ref.read(pantryPendingQuantitiesProvider.notifier).remove(itemId);
      _quantitySessions.remove(itemId);
    } on PantryFirestoreException {
      ref.read(pantryPendingQuantitiesProvider.notifier).remove(itemId);
      _quantitySessions.remove(itemId);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Pantry quantity undo failed: $error');
      debugPrint('$stackTrace');
      ref.read(pantryPendingQuantitiesProvider.notifier).remove(itemId);
      _quantitySessions.remove(itemId);
      throw PantryFirestoreException(
        'Unable to update ${session.item.name} quantity. Please try again.',
      );
    } finally {
      session.writeInProgress = false;
    }
  }

  /// +/- controls used by older call sites. Prefer [changeQuantityOptimistically].
  Future<void> adjustQuantity(String id, double delta) async {
    final currentItems = state.asData?.value;
    if (currentItems == null) return;

    final index = currentItems.indexWhere((item) => item.id == id);
    if (index == -1) return;

    changeQuantityOptimistically(item: currentItems[index], delta: delta);
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

    final connection = _requireFirestoreConnection(current);
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

  Future<void> _flushQuantity(_QuantityEditSession session) async {
    if (session.writeInProgress) return;
    session.writeInProgress = true;
    final target = session.pendingQuantity;

    try {
      final connection = _requireFirestoreConnection(session.item);
      await ref
          .read(pantryFirestoreServiceProvider)
          .updateQuantity(
            userId: connection.userId,
            itemId: connection.itemId,
            quantity: target,
          );
      session.writeCompleted = true;
      if (session.pendingQuantity == target) {
        session.onFlushed?.call(
          PantryQuantityWriteResult(
            itemId: session.item.id,
            itemName: session.item.name,
            quantityLabel: session.item
                .copyWith(quantity: target)
                .quantityLabel,
            success: true,
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Pantry quantity flush failed: $error');
      debugPrint('$stackTrace');
      ref
          .read(pantryPendingQuantitiesProvider.notifier)
          .remove(session.item.id);
      _quantitySessions.remove(session.item.id);
      session.onFlushed?.call(
        PantryQuantityWriteResult(
          itemId: session.item.id,
          itemName: session.item.name,
          quantityLabel: session.item.quantityLabel,
          success: false,
        ),
      );
    } finally {
      session.writeInProgress = false;
      final current = _quantitySessions[session.item.id];
      if (current != null &&
          identical(current, session) &&
          current.pendingQuantity != target) {
        current.debounceTimer?.cancel();
        current.debounceTimer = Timer(_quantityDebounce, () {
          unawaited(_flushQuantity(current));
        });
      }
    }
  }

  void _syncPendingQuantitiesWithStream(List<PantryItem> items) {
    final pending = ref.read(pantryPendingQuantitiesProvider);
    if (pending.isEmpty) return;

    final pendingNotifier = ref.read(pantryPendingQuantitiesProvider.notifier);
    for (final item in items) {
      final session = _quantitySessions[item.id];
      final overlay = pending[item.id];
      if (overlay == null) continue;
      if (session != null &&
          (session.writeInProgress ||
              session.debounceTimer?.isActive == true)) {
        continue;
      }
      if ((item.quantity - overlay).abs() < 0.001) {
        pendingNotifier.remove(item.id);
      }
    }
  }

  void _cancelQuantitySession(String itemId) {
    final session = _quantitySessions.remove(itemId);
    session?.debounceTimer?.cancel();
    ref.read(pantryPendingQuantitiesProvider.notifier).remove(itemId);
  }

  void _disposeQuantitySessions() {
    for (final session in _quantitySessions.values) {
      session.debounceTimer?.cancel();
    }
    _quantitySessions.clear();
  }
}

class _QuantityEditSession {
  _QuantityEditSession({
    required this.item,
    required this.originalQuantity,
    required this.pendingQuantity,
  });

  final PantryItem item;
  final double originalQuantity;
  double pendingQuantity;
  Timer? debounceTimer;
  bool writeInProgress = false;
  bool writeCompleted = false;
  void Function(PantryQuantityWriteResult result)? onFlushed;
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
  final pending = ref.watch(pantryPendingQuantitiesProvider);

  return itemsAsync.maybeWhen(
    data: (items) =>
        _applyFilters(_withPendingQuantities(items, pending), filters),
    orElse: () => const [],
  );
});

final pantrySummaryProvider = Provider<({int total, int lowStock})>((ref) {
  final itemsAsync = ref.watch(pantryItemsProvider);
  final pending = ref.watch(pantryPendingQuantitiesProvider);
  return itemsAsync.maybeWhen(
    data: (items) {
      final visible = _withPendingQuantities(items, pending);
      final lowStockCount = visible.where((item) => item.isLowStock).length;
      return (total: visible.length, lowStock: lowStockCount);
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

List<PantryItem> _withPendingQuantities(
  List<PantryItem> items,
  Map<String, double> pending,
) {
  if (pending.isEmpty) return items;
  return [
    for (final item in items)
      pending.containsKey(item.id)
          ? item.copyWith(quantity: pending[item.id]!)
          : item,
  ];
}

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
