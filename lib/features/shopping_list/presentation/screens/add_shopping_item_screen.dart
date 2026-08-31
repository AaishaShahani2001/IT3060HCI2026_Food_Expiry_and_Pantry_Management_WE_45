import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:go_router/go_router.dart';

class AddShoppingItemScreen extends StatefulWidget {
  final ShoppingItem? initialItem;

  const AddShoppingItemScreen({super.key, this.initialItem});

  @override
  State<AddShoppingItemScreen> createState() => _AddShoppingItemScreenState();
}

class _AddShoppingItemScreenState extends State<AddShoppingItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemNameController;
  late final TextEditingController _quantityController;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController(
      text: widget.initialItem?.name ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.initialItem?.quantity.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final item = ShoppingItem(
        name: _itemNameController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        isPurchased: widget.initialItem?.isPurchased ?? false,
      );

      context.pop(item);
    }
  }

  String? _validateItemName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.itemNameRequired;
    }

    return null;
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.quantityRequired;
    }

    final quantity = int.tryParse(value.trim());
    if (quantity == null || quantity <= 0) {
      return AppStrings.quantityInvalid;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? AppStrings.editShoppingItemTitle
              : AppStrings.addShoppingItemTitle,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _itemNameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AppStrings.itemName,
                        hintText: AppStrings.itemNameHint,
                        prefixIcon: const Icon(Icons.shopping_basket_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: _validateItemName,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: AppStrings.quantity,
                        hintText: AppStrings.quantityHint,
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: _validateQuantity,
                      onFieldSubmitted: (_) => _submitForm(),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _submitForm,
                      child: Text(
                        _isEditing
                            ? AppStrings.updateItem
                            : AppStrings.saveItem,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
