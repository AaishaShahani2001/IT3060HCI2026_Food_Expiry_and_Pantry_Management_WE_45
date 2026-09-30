import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../models/shopping_item.dart';
import 'low_stock_suggestion_settings_provider.dart';
import 'shopping_list_provider.dart';

/// Shopping-facing seam around Pantry state. Tests can override it without
/// initializing Firebase, while production still reuses Pantry's live stream.
final shoppingPantryItemsProvider = Provider<AsyncValue<List<PantryItem>>>(
  (ref) => ref.watch(pantryItemsProvider),
);

final lowStockDismissalsProvider =
    NotifierProvider<LowStockDismissalsNotifier, Map<String, Set<String>>>(
      LowStockDismissalsNotifier.new,
    );

final lowStockSuggestionExpansionProvider =
    NotifierProvider<LowStockSuggestionExpansionNotifier, Map<String, bool>>(
      LowStockSuggestionExpansionNotifier.new,
    );

class LowStockSuggestionExpansionNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};

  void toggle({required String uid}) {
    _requireCurrentUser(uid);
    state = {...state, uid: !(state[uid] ?? true)};
  }

  void _requireCurrentUser(String uid) {
    if (ref.read(shoppingAuthUidProvider).asData?.value != uid) {
      throw StateError('Your account changed. Please try again.');
    }
  }
}

final currentLowStockSuggestionExpandedProvider = Provider<bool>((ref) {
  final uid = ref.watch(shoppingAuthUidProvider).asData?.value;
  if (uid == null) return true;
  return ref.watch(lowStockSuggestionExpansionProvider)[uid] ?? true;
});

final shoppingCategoryExpansionProvider =
    NotifierProvider<
      ShoppingCategoryExpansionNotifier,
      Map<String, Map<String, bool>>
    >(ShoppingCategoryExpansionNotifier.new);

class ShoppingCategoryExpansionNotifier
    extends Notifier<Map<String, Map<String, bool>>> {
  @override
  Map<String, Map<String, bool>> build() => const {};

  void toggle({required String uid, required String category}) {
    _requireCurrentUser(uid);
    final categories = state[uid] ?? const <String, bool>{};
    state = {
      ...state,
      uid: {...categories, category: !(categories[category] ?? true)},
    };
  }

  void setExpanded({
    required String uid,
    required String category,
    required bool expanded,
  }) {
    _requireCurrentUser(uid);
    final categories = state[uid] ?? const <String, bool>{};
    state = {
      ...state,
      uid: {...categories, category: expanded},
    };
  }

  void forgetCategory({required String uid, required String category}) {
    _requireCurrentUser(uid);
    final categories = {...?state[uid]}..remove(category);
    state = {...state, uid: categories};
  }

  void _requireCurrentUser(String uid) {
    if (ref.read(shoppingAuthUidProvider).asData?.value != uid) {
      throw StateError('Your account changed. Please try again.');
    }
  }
}

final currentShoppingCategoryExpansionProvider = Provider<Map<String, bool>>((
  ref,
) {
  final uid = ref.watch(shoppingAuthUidProvider).asData?.value;
  if (uid == null) return const {};
  return ref.watch(shoppingCategoryExpansionProvider)[uid] ?? const {};
});

class LowStockDismissalsNotifier extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => const {};

  void dismiss({required String uid, required String pantryItemId}) {
    _requireCurrentUser(uid);
    state = {
      ...state,
      uid: {...?state[uid], pantryItemId},
    };
  }

  void restore({required String uid, required String pantryItemId}) {
    _requireCurrentUser(uid);
    final dismissed = {...?state[uid]}..remove(pantryItemId);
    state = {...state, uid: dismissed};
  }

  Set<String> dismissAll({
    required String uid,
    required Iterable<String> pantryItemIds,
  }) {
    _requireCurrentUser(uid);
    final previous = state[uid] ?? const <String>{};
    final newlyDismissed = pantryItemIds
        .where((id) => !previous.contains(id))
        .toSet();
    state = {
      ...state,
      uid: {...previous, ...newlyDismissed},
    };
    return newlyDismissed;
  }

  void restoreAll({required String uid, required Set<String> pantryItemIds}) {
    _requireCurrentUser(uid);
    final dismissed = {...?state[uid]}..removeAll(pantryItemIds);
    state = {...state, uid: dismissed};
  }

  void _requireCurrentUser(String uid) {
    if (ref.read(shoppingAuthUidProvider).asData?.value != uid) {
      throw StateError('Your account changed. Please try again.');
    }
  }
}

final currentLowStockDismissalsProvider = Provider<Set<String>>((ref) {
  final uid = ref.watch(shoppingAuthUidProvider).asData?.value;
  if (uid == null) return const {};
  return ref.watch(lowStockDismissalsProvider)[uid] ?? const {};
});

List<PantryItem> lowStockShoppingSuggestions({
  required Iterable<PantryItem> pantryItems,
  required Iterable<ShoppingItem> shoppingItems,
  Set<String> dismissedPantryItemIds = const {},
  bool enabled = true,
  Map<PantryCategory, int>? categoryThresholds,
}) {
  if (!enabled) return const [];
  String normalized(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  final shoppingNames = shoppingItems
      .map((item) => normalized(item.name))
      .toSet();
  final linkedPantryIds = shoppingItems
      .map((item) => item.sourcePantryItemId)
      .whereType<String>()
      .toSet();

  final suggestions = pantryItems.where((item) {
    final isLowStock = categoryThresholds == null
        ? item.isLowStock || item.isOutOfStock
        : item.quantity <=
              (categoryThresholds[item.category] ?? 1) * item.minQuantity;
    return item.isConnectedToFirestore &&
        item.name.trim().isNotEmpty &&
        item.quantity.isFinite &&
        isLowStock &&
        !dismissedPantryItemIds.contains(item.firestoreId) &&
        !shoppingNames.contains(normalized(item.name)) &&
        !linkedPantryIds.contains(item.firestoreId);
  }).toList();
  suggestions.sort((a, b) {
    final byQuantity = a.quantity.compareTo(b.quantity);
    if (byQuantity != 0) return byQuantity;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return suggestions;
}

final lowStockShoppingSuggestionsProvider = Provider<List<PantryItem>>((ref) {
  final pantry = ref.watch(shoppingPantryItemsProvider).asData?.value;
  final shopping = ref.watch(shoppingListProvider).asData?.value;
  final dismissed = ref.watch(currentLowStockDismissalsProvider);
  final settings = ref.watch(lowStockSuggestionSettingsProvider);
  if (pantry == null || shopping == null) return const [];
  return lowStockShoppingSuggestions(
    pantryItems: pantry,
    shoppingItems: shopping,
    dismissedPantryItemIds: dismissed,
    enabled: settings.enabled,
    categoryThresholds: settings.thresholds,
  );
});
