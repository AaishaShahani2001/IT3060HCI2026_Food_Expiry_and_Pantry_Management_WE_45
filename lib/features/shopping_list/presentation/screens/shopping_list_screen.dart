import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/widgets/shopping_item_tile.dart';
import 'package:go_router/go_router.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final List<ShoppingItem> _items = [];

  Future<void> _openAddItemScreen() async {
    final item = await context.push<ShoppingItem>(AppRoutes.addShoppingItem);

    if (!mounted || item == null) return;

    setState(() => _items.add(item));
  }

  void _updatePurchasedStatus(int index, bool isPurchased) {
    setState(() {
      _items[index] = _items[index].copyWith(isPurchased: isPurchased);
    });
  }

  Future<void> _editItem(int index) async {
    final updatedItem = await context.push<ShoppingItem>(
      AppRoutes.addShoppingItem,
      extra: _items[index],
    );

    if (!mounted || updatedItem == null) return;

    setState(() => _items[index] = updatedItem);
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Widget _buildAddItemButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _openAddItemScreen,
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

  Widget _buildItemList() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                itemCount: _items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return ShoppingItemTile(
                    item: _items[index],
                    onPurchasedChanged: (isPurchased) =>
                        _updatePurchasedStatus(index, isPurchased),
                    onEdit: () => _editItem(index),
                    onDelete: () => _deleteItem(index),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _buildAddItemButton(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.shoppingListTitle,
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            color: AppColors.darkGreen,
          ),
        ),
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _items.isEmpty ? _buildEmptyState(context) : _buildItemList(),
      ),
    );
  }
}
