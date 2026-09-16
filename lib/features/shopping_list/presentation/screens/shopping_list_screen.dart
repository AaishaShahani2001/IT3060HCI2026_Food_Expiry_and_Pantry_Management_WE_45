import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/widgets/shopping_item_tile.dart';
import 'package:go_router/go_router.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  bool _isBusy = false;
  bool _showProgress = false;
  int _operationToken = 0;

  String? get _uid => ref.read(shoppingAuthUidProvider).asData?.value;

  bool _sameSession(String? uid, int token) =>
      mounted && token == _operationToken && uid != null && uid == _uid;

  String _errorMessage(Object error) {
    if (error is ShoppingListDeleteException) {
      return '${error.deletedItemIds.length} items were already deleted, but the '
          'remaining deletion failed. Your list is kept visible; reload to '
          'check it or retry deletion. ${_errorMessage(error.cause)}';
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Firestore permission-denied: ${error.message ?? 'Access denied.'} '
            'Ask the team to check your access rules.';
      }
      if (error.code == 'unavailable') {
        return 'Firestore is unavailable. Check your connection and retry.';
      }
      return 'Firestore ${error.code}: ${error.message ?? 'Please try again.'}';
    }
    if (error is StateError) return error.message;
    if (error is FormatException) {
      return 'A saved shopping item could not be read. Please ask the team to check its data.';
    }
    return 'Could not complete the shopping operation. Please try again.';
  }

  void _showError(Object error, {VoidCallback? retry}) {
    if (!mounted) return;
    debugPrint('Shopping List error: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_errorMessage(error)),
        duration: const Duration(seconds: 8),
        action: retry == null
            ? null
            : SnackBarAction(label: 'Retry', onPressed: retry),
      ),
    );
  }

  Future<void> _openAddItemScreen() async {
    if (_isBusy || _uid == null) return;
    final uid = _uid;
    final token = ++_operationToken;
    setState(() => _isBusy = true);
    try {
      final item = await context.push<ShoppingItem>(AppRoutes.addShoppingItem);
      if (!_sameSession(uid, token) || item == null) return;
      await _saveItem(item, uid!, token);
    } finally {
      if (mounted && token == _operationToken) setState(() => _isBusy = false);
    }
  }

  Future<void> _saveItem(ShoppingItem item, String uid, int token) async {
    setState(() => _showProgress = true);
    try {
      await ref.read(shoppingListProvider.notifier).addItem(item);
    } catch (error) {
      if (_sameSession(uid, token)) {
        _showError(error, retry: () => _retrySave(item, uid));
      }
    } finally {
      if (_sameSession(uid, token)) setState(() => _showProgress = false);
    }
  }

  Future<void> _retrySave(ShoppingItem item, String uid) async {
    if (_isBusy || uid != _uid) return;
    final token = ++_operationToken;
    setState(() => _isBusy = true);
    try {
      await _saveItem(item, uid, token);
    } finally {
      if (mounted && token == _operationToken) setState(() => _isBusy = false);
    }
  }

  void _updatePurchasedStatus(ShoppingItem item, bool isPurchased) {
    if (_isBusy || _selectionMode || item.id == null) return;
    try {
      ref
          .read(shoppingListProvider.notifier)
          .togglePurchased(item.id!, isPurchased);
    } catch (error) {
      _showError(error);
    }
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
      ref.read(shoppingListProvider.notifier).updateItem(item.id!, updatedItem);
    } catch (error) {
      if (_sameSession(uid, token)) _showError(error);
    } finally {
      if (mounted && token == _operationToken) setState(() => _isBusy = false);
    }
  }

  void _selectItem(ShoppingItem item, {bool enter = false}) {
    if (_isBusy || item.id == null) return;
    setState(() {
      if (enter) {
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

  Future<void> _confirmDelete(List<String> ids, {bool single = false}) async {
    if (_isBusy || ids.isEmpty || _uid == null) return;
    final uid = _uid;
    final token = ++_operationToken;
    final items = ref.read(shoppingListProvider).asData?.value ?? [];
    final all = !single && ids.length == items.length;
    final title = single || ids.length == 1
        ? 'Delete item?'
        : all
        ? 'Delete all items?'
        : 'Delete selected items?';
    final message = single || ids.length == 1
        ? 'Are you sure you want to delete this item?'
        : all
        ? 'Are you sure you want to delete all items from your shopping list?'
        : 'Are you sure you want to delete ${ids.length} selected items?';
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
                backgroundColor: AppColors.unreadBadge,
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
        setState(() {
          _selectionMode = false;
          _selectedIds.clear();
        });
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
    _cancelSelection();
    final uid = _uid;
    final token = ++_operationToken;
    setState(() => _isBusy = true);
    try {
      await ref.read(shoppingListProvider.notifier).reload();
    } catch (error) {
      if (_sameSession(uid, token)) _showError(error);
    } finally {
      if (mounted && token == _operationToken) setState(() => _isBusy = false);
    }
  }

  Widget _buildAddItemButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isBusy ? null : _openAddItemScreen,
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addItem),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 42,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.shoppingListEmpty,
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  color: AppColors.darkGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.shoppingListEmptyDescription,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              _buildAddItemButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemList(List<ShoppingItem> items) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ShoppingItemTile(
                    key: ValueKey(item.id),
                    item: item,
                    enabled: !_isBusy,
                    selectionMode: _selectionMode,
                    isSelected: _selectedIds.contains(item.id),
                    onLongPress: () => _selectItem(item, enter: true),
                    onSelectionTap: () => _selectItem(item),
                    onPurchasedChanged: (value) =>
                        _updatePurchasedStatus(item, value),
                    onEdit: () => _editItem(item),
                    onDelete: () {
                      if (item.id != null) {
                        _confirmDelete([item.id!], single: true);
                      }
                    },
                  );
                },
              ),
            ),
            if (!_selectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: _buildAddItemButton(),
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
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(shoppingAuthUidProvider);
    final itemsAsync = ref.watch(shoppingListProvider);
    // Never render retained AsyncData while reloading for a different account.
    final items = itemsAsync.isLoading
        ? <ShoppingItem>[]
        : itemsAsync.asData?.value ?? [];
    final allSelected =
        items.isNotEmpty &&
        items.every(
          (item) => item.id != null && _selectedIds.contains(item.id),
        );

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
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(error),
        data: (items) =>
            items.isEmpty ? _buildEmptyState(context) : _buildItemList(items),
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
              color: AppColors.darkGreen,
            ),
          ),
          actions: _selectionMode
              ? [
                  TextButton(
                    onPressed: _isBusy ? null : () => _selectAll(items),
                    child: Text(allSelected ? 'Deselect All' : 'Select All'),
                  ),
                  IconButton(
                    onPressed: _isBusy || _selectedIds.isEmpty
                        ? null
                        : () => _confirmDelete(_selectedIds.toList()),
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.unreadBadge,
                    tooltip: 'Delete selected items',
                  ),
                ]
              : [
                  if (auth.asData?.value != null)
                    IconButton(
                      onPressed: _isBusy || itemsAsync.isLoading
                          ? null
                          : _reload,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reload shopping list',
                    ),
                ],
          backgroundColor: AppColors.cream,
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
