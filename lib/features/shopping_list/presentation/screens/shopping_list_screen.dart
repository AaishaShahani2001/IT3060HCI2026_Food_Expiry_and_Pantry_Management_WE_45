import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/utils/pantry_item_actions.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_form.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/food_item_suggestions.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_item_metadata.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/shopping_error_message.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/shopping_snackbar.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/low_stock_suggestion_settings_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_pantry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/widgets/low_stock_suggestions_card.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/widgets/shopping_item_tile.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/widgets/shopping_category_section.dart';
import 'package:go_router/go_router.dart';

enum _ShoppingFilter { all, toBuy, bought }

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  _ShoppingFilter _filter = _ShoppingFilter.all;
  bool _selectionMode = false;
  bool _isBusy = false;
  bool _showProgress = false;
  int _operationToken = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ShoppingItem> _visibleItems(List<ShoppingItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final matchesTab = switch (_filter) {
        _ShoppingFilter.all => true,
        _ShoppingFilter.toBuy => !item.isPurchased,
        _ShoppingFilter.bought => item.isPurchased,
      };
      return matchesTab && item.name.toLowerCase().contains(query);
    }).toList();
  }

  String? get _uid => ref.read(shoppingAuthUidProvider).asData?.value;

  bool _sameSession(String? uid, int token) =>
      mounted && token == _operationToken && uid != null && uid == _uid;

  String _errorMessage(Object error) => shoppingErrorMessage(error);

  void _showError(Object error, {VoidCallback? retry, String? message}) {
    if (!mounted) return;
    debugPrint('Shopping List error: $error');
    ShoppingSnackBar.show(
      context,
      message: message ?? _errorMessage(error),
      duration: ShoppingSnackBar.error,
      snackBarAction: retry == null
          ? null
          : SnackBarAction(label: 'Retry', onPressed: retry),
    );
  }

  Future<void> _openAddItemScreen() async {
    if (_isBusy || _uid == null) return;
    FocusScope.of(context).unfocus();
    final uid = _uid;
    final token = ++_operationToken;
    setState(() => _isBusy = true);
    try {
      final item = await context.push<ShoppingItem>(
        Uri(
          path: AppRoutes.addShoppingItem,
          queryParameters: {'name': _searchController.text.trim()},
        ).toString(),
      );
      if (!_sameSession(uid, token) || item == null) return;
      setState(() {
        _filter = _ShoppingFilter.all;
        _searchController.clear();
      });
      ref
          .read(shoppingCategoryExpansionProvider.notifier)
          .setExpanded(
            uid: uid!,
            category: resolvedShoppingCategory(item),
            expanded: true,
          );
    } finally {
      if (mounted && token == _operationToken) setState(() => _isBusy = false);
    }
  }

  Future<bool> _persistChange(Future<void> Function() save) async {
    final uid = _uid;
    final token = ++_operationToken;
    setState(() {
      _isBusy = true;
      _showProgress = true;
    });
    try {
      await save();
      return _sameSession(uid, token);
    } catch (error) {
      if (_sameSession(uid, token)) _showError(error);
      return false;
    } finally {
      if (mounted && token == _operationToken) {
        setState(() {
          _isBusy = false;
          _showProgress = false;
        });
      }
    }
  }

  Future<void> _updatePurchasedStatus(
    ShoppingItem item,
    bool isPurchased,
  ) async {
    if (_isBusy || _selectionMode || item.id == null) return;
    final saved = await _persistChange(
      () => ref
          .read(shoppingListProvider.notifier)
          .togglePurchased(item.id!, isPurchased),
    );
    if (saved && isPurchased && mounted) _offerPantryQuickAdd(item);
  }

  void _offerPantryQuickAdd(ShoppingItem item) {
    final pantryItems =
        ref.read(shoppingPantryItemsProvider).asData?.value ?? const [];
    final existing = pantryItems
        .where(
          (pantryItem) =>
              pantryItem.name.trim().toLowerCase() ==
              item.name.trim().toLowerCase(),
        )
        .firstOrNull;
    ShoppingSnackBar.show(
      context,
      message: existing == null
          ? '${item.name} marked Bought. Add it to Pantry?'
          : '${item.name} marked Bought. Update its Pantry quantity?',
      duration: ShoppingSnackBar.action,
      snackBarAction: SnackBarAction(
        label: existing == null ? 'Add to Pantry' : 'Update Pantry',
        onPressed: () {
          if (!mounted) return;
          if (existing != null) {
            unawaited(openPantryItemEditor(context, existing));
            return;
          }
          unawaited(
            openPantryAddItem(
              context,
              prefill: PantryItemFormPrefill(
                name: item.name,
                quantity: item.quantity.toDouble(),
                unit: item.unit,
                category: pantryCategoryForShoppingCategory(
                  resolvedShoppingCategory(item),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addLowStockSuggestion(PantryItem item) async {
    if (_isBusy || _selectionMode) return;
    ShoppingItem? added;
    final threshold = ref
        .read(lowStockSuggestionSettingsProvider)
        .effectiveThresholdFor(item);
    final saved = await _persistChange(() async {
      added = await ref
          .read(shoppingListProvider.notifier)
          .addLowStockSuggestion(item, threshold: threshold);
    });
    if (!saved || !mounted) return;
    ShoppingSnackBar.show(
      context,
      message: added == null
          ? '${item.name} is already in your Shopping List.'
          : '${item.name} added to your Shopping List.',
    );
  }

  void _dismissLowStockSuggestion(PantryItem item) {
    if (_isBusy || _selectionMode) return;
    final uid = _uid;
    final pantryItemId = item.firestoreId;
    if (uid == null || pantryItemId == null) return;
    ref
        .read(lowStockDismissalsProvider.notifier)
        .dismiss(uid: uid, pantryItemId: pantryItemId);
    ShoppingSnackBar.show(
      context,
      message: '${item.name} suggestion dismissed.',
      duration: ShoppingSnackBar.action,
      snackBarAction: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          if (!mounted || uid != _uid) return;
          ref
              .read(lowStockDismissalsProvider.notifier)
              .restore(uid: uid, pantryItemId: pantryItemId);
        },
      ),
    );
  }

  Future<void> _dismissAllLowStockSuggestions(List<PantryItem> items) async {
    if (_isBusy || _selectionMode || items.isEmpty) return;
    final uid = _uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dismiss all suggestions?'),
        content: const Text(
          'This will hide all current low-stock suggestions for this session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dismiss All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || uid != _uid) return;
    final newlyDismissed = ref
        .read(lowStockDismissalsProvider.notifier)
        .dismissAll(
          uid: uid,
          pantryItemIds: items.map((item) => item.firestoreId).whereType(),
        );
    if (newlyDismissed.isEmpty) return;
    ShoppingSnackBar.show(
      context,
      message:
          '${newlyDismissed.length} low-stock ${newlyDismissed.length == 1 ? 'suggestion' : 'suggestions'} dismissed.',
      duration: ShoppingSnackBar.action,
      snackBarAction: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          if (!mounted || uid != _uid) return;
          ref
              .read(lowStockDismissalsProvider.notifier)
              .restoreAll(uid: uid, pantryItemIds: newlyDismissed);
        },
      ),
    );
  }

  Future<void> _addAllLowStockSuggestions(List<PantryItem> items) async {
    if (_isBusy || _selectionMode || items.isEmpty) return;
    final uid = _uid;
    if (uid == null) return;
    if (items.length > 5) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add all suggestions?'),
          content: Text(
            'Add ${items.length} suggested items to your Shopping List?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add All'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || uid != _uid) return;
    }

    var addedCount = 0;
    final thresholds = ref.read(lowStockSuggestionSettingsProvider).thresholds;
    final saved = await _persistChange(() async {
      addedCount = await ref
          .read(shoppingListProvider.notifier)
          .addLowStockSuggestions(items, categoryThresholds: thresholds);
    });
    if (!saved || !mounted) return;
    ShoppingSnackBar.show(
      context,
      message: addedCount == 0
          ? 'All suggested items are already in your Shopping List.'
          : '$addedCount ${addedCount == 1 ? 'item' : 'items'} added to your Shopping List.',
    );
  }

  Future<void> _updateQuantity(ShoppingItem item, int quantity) async {
    if (_isBusy ||
        _selectionMode ||
        item.id == null ||
        quantity < 1 ||
        quantity > 100) {
      return;
    }
    await _persistChange(
      () => ref
          .read(shoppingListProvider.notifier)
          .updateItem(item.id!, item.copyWith(quantity: quantity)),
    );
  }

  Future<void> _editItem(ShoppingItem item) async {
    if (_isBusy || _selectionMode || item.id == null) return;
    final uid = _uid;
    final token = ++_operationToken;
    setState(() => _isBusy = true);
    try {
      final updatedItem = await context.push<ShoppingItem>(
        AppRoutes.addShoppingItem,
        extra: item,
      );
      if (!_sameSession(uid, token) || updatedItem == null) return;
      // The form saves before returning, so cancellation/failure retains input.
    } catch (error) {
      if (_sameSession(uid, token)) _showError(error);
    } finally {
      if (mounted && token == _operationToken) {
        setState(() {
          _isBusy = false;
          _showProgress = false;
        });
      }
    }
  }

  void _selectItem(ShoppingItem item, {bool enter = false}) {
    if (_isBusy || item.id == null) return;
    setState(() {
      if (enter) {
        FocusScope.of(context).unfocus();
        _selectionMode = true;
        _selectedIds.add(item.id!);
      } else if (!_selectedIds.remove(item.id)) {
        _selectedIds.add(item.id!);
      }
    });
  }

  void _cancelSelection() {
    if (_isBusy) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<ShoppingItem> items) {
    if (_isBusy) return;
    final ids = items.map((item) => item.id).whereType<String>().toSet();
    setState(() {
      if (ids.every(_selectedIds.contains)) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  Future<void> _showCategoryActions(String category) async {
    if (_isBusy || _selectionMode || _uid == null) return;
    final uid = _uid;
    final title = shoppingCategoryTitle(category);
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(sheetContext).colorScheme.error,
            ),
            title: Text('Delete all items in $title'),
            textColor: Theme.of(sheetContext).colorScheme.error,
            onTap: () => Navigator.pop(sheetContext, true),
          ),
        ),
      ),
    );
    if (delete != true || !mounted || uid != _uid) return;
    await _confirmCategoryDelete(category, uid!);
  }

  Future<void> _confirmCategoryDelete(String category, String uid) async {
    if (_isBusy || uid != _uid) return;
    final items = ref.read(shoppingListProvider).asData?.value ?? const [];
    final categoryItems = items
        .where((item) => resolvedShoppingCategory(item) == category)
        .toList();
    final ids = categoryItems
        .map((item) => item.id)
        .whereType<String>()
        .toList();
    if (ids.length != categoryItems.length || ids.isEmpty) {
      _showError(
        StateError('The category changed.'),
        message: 'This category changed. Refresh your list and try again.',
      );
      return;
    }
    final title = shoppingCategoryTitle(category);
    final count = ids.length;
    await _confirmDelete(
      ids,
      titleOverride: 'Delete $title items?',
      messageOverride:
          'This will remove ${count == 1 ? '1 item' : 'all $count items'} in the $title category from your Shopping List.',
      successMessage:
          '$count ${count == 1 ? 'item' : 'items'} removed from $title.',
      categoryToForget: category,
    );
  }

  Future<void> _confirmDelete(
    List<String> ids, {
    bool single = false,
    String? titleOverride,
    String? messageOverride,
    String? successMessage,
    String? categoryToForget,
  }) async {
    if (_isBusy || ids.isEmpty || _uid == null) return;
    final uid = _uid;
    final token = ++_operationToken;
    final items = ref.read(shoppingListProvider).asData?.value ?? [];
    final all = !single && ids.length == _visibleItems(items).length;
    final title =
        titleOverride ??
        (single || ids.length == 1
            ? 'Delete item?'
            : all
            ? 'Delete all selected items?'
            : 'Delete selected items?');
    final message =
        messageOverride ??
        (single || ids.length == 1
            ? 'Are you sure you want to delete this item?'
            : ids.length == items.length
            ? 'Are you sure you want to delete all items from your shopping list?'
            : 'Are you sure you want to delete ${ids.length} selected items?');
    setState(() => _isBusy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (!_sameSession(uid, token) || confirmed != true) return;
      setState(() => _showProgress = true);
      await ref.read(shoppingListProvider.notifier).deleteItems(ids);
      if (_sameSession(uid, token)) {
        if (categoryToForget != null) {
          ref
              .read(shoppingCategoryExpansionProvider.notifier)
              .forgetCategory(uid: uid!, category: categoryToForget);
        }
        setState(() {
          _selectionMode = false;
          _selectedIds.clear();
        });
        if (successMessage != null) {
          if (!mounted) return;
          ShoppingSnackBar.show(context, message: successMessage);
        }
      }
    } catch (error) {
      if (_sameSession(uid, token)) _showError(error);
    } finally {
      if (mounted && token == _operationToken) {
        setState(() {
          _isBusy = false;
          _showProgress = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    if (_isBusy) return;
    final hadData = ref.read(shoppingListProvider).asData != null;
    _cancelSelection();
    final uid = _uid;
    final token = ++_operationToken;
    setState(() => _isBusy = true);
    try {
      await ref.read(shoppingListProvider.notifier).reload();
    } catch (error) {
      if (_sameSession(uid, token)) {
        _showError(
          error,
          message: hadData
              ? "Couldn't refresh. Showing your current list."
              : null,
        );
      }
    } finally {
      if (mounted && token == _operationToken) setState(() => _isBusy = false);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 42,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.shoppingListEmpty,
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.shoppingListEmptyDescription,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _isBusy ? null : _openAddItemScreen,
                icon: const Icon(Icons.add),
                label: const Text('Add your first item'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(List<ShoppingItem> items) {
    final colors = Theme.of(context).colorScheme;
    final bought = items.where((item) => item.isPurchased).length;
    final labels = [
      'ALL (${items.length})',
      'TO BUY (${items.length - bought})',
      'BOUGHT ($bought)',
    ];
    return Row(
      children: [
        for (final filter in _ShoppingFilter.values) ...[
          if (filter.index > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: _filter == filter,
              child: OutlinedButton(
                onPressed: _isBusy || _selectionMode
                    ? null
                    : () => setState(() => _filter = filter),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _filter == filter
                      ? colors.secondary
                      : colors.surfaceContainerHighest,
                  foregroundColor: _filter == filter
                      ? colors.onSecondary
                      : colors.onSurface,
                  disabledForegroundColor: _filter == filter
                      ? colors.onSecondary
                      : colors.onSurfaceVariant,
                  side: BorderSide(
                    color: _filter == filter
                        ? colors.secondary
                        : colors.outline.withValues(alpha: 0.6),
                  ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(labels[filter.index], textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearch() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('shopping-search'),
            controller: _searchController,
            enabled: !_isBusy && !_selectionMode,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Add item or search...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _isBusy || _selectionMode
                          ? null
                          : () => setState(_searchController.clear),
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colors.outline.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
        if (!_selectionMode) ...[
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Add shopping item',
            onPressed: _isBusy ? null : _openAddItemScreen,
            style: IconButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.add),
          ),
        ],
      ],
    );
  }

  Widget _buildItemRow(ShoppingItem item) {
    final uid = _uid;
    return ShoppingItemTile(
      key: ValueKey((uid, item.id)),
      item: item,
      enabled: !_isBusy,
      selectionMode: _selectionMode,
      isSelected: _selectedIds.contains(item.id),
      onLongPress: () => _selectItem(item, enter: true),
      onSelectionTap: () => _selectItem(item),
      onPurchasedChanged: (value) => _updatePurchasedStatus(item, value),
      onQuantityChanged: (value) => _updateQuantity(item, value),
      onEdit: () {
        // A menu opened under a previous account must not operate on this one.
        if (uid != null && uid == _uid) _editItem(item);
      },
      onDelete: () {
        if (uid != null && uid == _uid && item.id != null) {
          _confirmDelete([item.id!], single: true);
        }
      },
    );
  }

  Widget _buildItemList(List<ShoppingItem> items) {
    final suggestions = ref.watch(lowStockShoppingSuggestionsProvider);
    final lowStockSuggestionsExpanded = ref.watch(
      currentLowStockSuggestionExpandedProvider,
    );
    final categoryExpansion = ref.watch(
      currentShoppingCategoryExpansionProvider,
    );
    final visible = _visibleItems(items);
    final allSelected =
        visible.isNotEmpty &&
        visible.every((item) => _selectedIds.contains(item.id));
    final groups = <String, List<ShoppingItem>>{};
    for (final item in visible) {
      groups.putIfAbsent(resolvedShoppingCategory(item), () => []).add(item);
    }
    final categoryOrder = [...foodItemSuggestionCategories.keys, 'Other'];
    final categories = [
      ...categoryOrder.where(groups.containsKey),
      ...groups.keys.where((category) => !categoryOrder.contains(category)),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  if (!_selectionMode && suggestions.isNotEmpty) ...[
                    LowStockSuggestionsCard(
                      items: suggestions,
                      enabled: !_isBusy,
                      onAdd: _addLowStockSuggestion,
                      onDismiss: _dismissLowStockSuggestion,
                      onAddAll: () => _addAllLowStockSuggestions(suggestions),
                      onDismissAll: () =>
                          _dismissAllLowStockSuggestions(suggestions),
                      expanded: lowStockSuggestionsExpanded,
                      onToggleExpanded: () {
                        final uid = _uid;
                        if (uid == null) return;
                        ref
                            .read(lowStockSuggestionExpansionProvider.notifier)
                            .toggle(uid: uid);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildFilters(items),
                  const SizedBox(height: 12),
                  _buildSearch(),
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          const Text('Select matching items to delete'),
                          TextButton(
                            onPressed: _isBusy
                                ? null
                                : () => _selectAll(visible),
                            child: Text(
                              allSelected ? 'Deselect All' : 'Select All',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: CustomScrollView(
                  key: ValueKey(('shopping-scroll', _uid)),
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (items.isEmpty &&
                        _filter == _ShoppingFilter.all &&
                        _searchController.text.trim().isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context),
                      )
                    else if (visible.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off, size: 36),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.trim().isNotEmpty
                                      ? 'No matching items'
                                      : _filter == _ShoppingFilter.toBuy
                                      ? 'No items to buy'
                                      : 'No bought items yet',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () => setState(() {
                                          _filter = _ShoppingFilter.all;
                                          _searchController.clear();
                                        }),
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (index.isOdd) return const SizedBox(height: 12);
                            final category = categories[index ~/ 2];
                            return ShoppingCategorySection(
                              key: ValueKey(category),
                              category: category,
                              count: groups[category]!.length,
                              expanded:
                                  _selectionMode ||
                                  (categoryExpansion[category] ?? true),
                              onToggle: _isBusy || _selectionMode
                                  ? null
                                  : () {
                                      final uid = _uid;
                                      if (uid == null) return;
                                      ref
                                          .read(
                                            shoppingCategoryExpansionProvider
                                                .notifier,
                                          )
                                          .toggle(uid: uid, category: category);
                                    },
                              onLongPress: _isBusy || _selectionMode
                                  ? null
                                  : () => _showCategoryActions(category),
                              children: groups[category]!
                                  .map(_buildItemRow)
                                  .toList(),
                            );
                          }, childCount: categories.length * 2 - 1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isBusy ? null : _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shoppingAuthUidProvider, (previous, next) {
      if (previous?.asData?.value != next.asData?.value) {
        setState(() {
          ++_operationToken;
          _isBusy = false;
          _showProgress = false;
          _selectionMode = false;
          _selectedIds.clear();
          _filter = _ShoppingFilter.all;
          _searchController.clear();
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(shoppingAuthUidProvider);
    final itemsAsync = ref.watch(shoppingListProvider);

    Widget body;
    if (auth.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (auth.hasError) {
      body = Center(
        child: TextButton(
          onPressed: () => ref.invalidate(shoppingAuthUidProvider),
          child: const Text('Unable to check your account. Retry'),
        ),
      );
    } else if (auth.asData?.value == null) {
      body = const Center(
        child: Text('Please sign in to use your shopping list.'),
      );
    } else {
      body = itemsAsync.when(
        skipLoadingOnReload: false,
        // Keep the scroll view mounted while RefreshIndicator awaits reload.
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(error),
        data: _buildItemList,
      );
    }

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectionMode) _cancelSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selectionMode
              ? IconButton(
                  onPressed: _isBusy ? null : _cancelSelection,
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel selection',
                )
              : null,
          title: Text(
            _selectionMode
                ? '${_selectedIds.length} selected'
                : AppStrings.shoppingListTitle,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          actions: _selectionMode
              ? [
                  IconButton(
                    onPressed: _isBusy || _selectedIds.isEmpty
                        ? null
                        : () => _confirmDelete(_selectedIds.toList()),
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Delete selected items',
                  ),
                ]
              : null,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_showProgress) const LinearProgressIndicator(),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
