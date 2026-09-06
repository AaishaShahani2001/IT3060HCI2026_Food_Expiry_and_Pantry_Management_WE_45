import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/food_item_suggestions.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/quantity_presets.dart';
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
  final FocusNode _itemNameFocusNode = FocusNode();

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
    _itemNameController.addListener(_refreshFormOptions);
    _quantityController.addListener(_refreshFormOptions);
  }

  @override
  void dispose() {
    _itemNameController.removeListener(_refreshFormOptions);
    _quantityController.removeListener(_refreshFormOptions);
    _itemNameController.dispose();
    _quantityController.dispose();
    _itemNameFocusNode.dispose();
    super.dispose();
  }

  void _refreshFormOptions() {
    setState(() {});
  }

  void _setQuantity(int quantity) {
    _quantityController.text = quantity.toString();
    _quantityController.selection = TextSelection.collapsed(
      offset: _quantityController.text.length,
    );
  }

  Iterable<String> _findFoodSuggestions(TextEditingValue textEditingValue) {
    final query = textEditingValue.text.trim().toLowerCase();

    if (query.isEmpty) {
      return const Iterable<String>.empty();
    }

    return foodItemSuggestions.where(
      (item) => item.toLowerCase().startsWith(query),
    );
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
    if (quantity == null || quantity < 1 || quantity > 100) {
      return AppStrings.quantityInvalid;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final quickQuantities = quantityPresetsFor(_itemNameController.text);
    final selectedQuantity = _quantityController.text.trim();

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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return RawAutocomplete<String>(
                          textEditingController: _itemNameController,
                          focusNode: _itemNameFocusNode,
                          optionsBuilder: _findFoodSuggestions,
                          fieldViewBuilder:
                              (context, controller, focusNode, onSubmitted) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.itemName,
                                    hintText: AppStrings.itemNameHint,
                                    prefixIcon: const Icon(
                                      Icons.shopping_basket_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  validator: _validateItemName,
                                  onFieldSubmitted: (_) => onSubmitted(),
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            final matches = options.toList();

                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: AppColors.white,
                                elevation: 4,
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 240,
                                    ),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      shrinkWrap: true,
                                      itemCount: matches.length,
                                      itemBuilder: (context, index) {
                                        final item = matches[index];
                                        final isHighlighted =
                                            AutocompleteHighlightedOption.of(
                                              context,
                                            ) ==
                                            index;

                                        return InkWell(
                                          onTap: () => onSelected(item),
                                          child: Container(
                                            color: isHighlighted
                                                ? AppColors.softGreen
                                                : null,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Text(
                                              item,
                                              style: textTheme.bodyLarge
                                                  ?.copyWith(
                                                    color: AppColors.darkGreen,
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Quick Quantity',
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: quickQuantities.map((quantity) {
                        final isSelected =
                            selectedQuantity == quantity.toString();

                        return ChoiceChip(
                          label: Text(quantity.toString()),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: AppColors.softGreen,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.cardBorder,
                          ),
                          labelStyle: textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? AppColors.darkGreen
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          onSelected: (_) => _setQuantity(quantity),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    MenuAnchor(
                      alignmentOffset: const Offset(0, 4),
                      menuChildren: quantityDropdownOptions.map((quantity) {
                        return MenuItemButton(
                          onPressed: () => _setQuantity(quantity),
                          child: SizedBox(
                            width: 160,
                            child: Text(quantity.toString()),
                          ),
                        );
                      }).toList(),
                      builder: (context, menuController, child) {
                        return TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: AppStrings.quantity,
                            hintText: AppStrings.quantityHint,
                            prefixIcon: const Icon(Icons.numbers),
                            suffixIcon: IconButton(
                              onPressed: () {
                                if (menuController.isOpen) {
                                  menuController.close();
                                } else {
                                  menuController.open();
                                }
                              },
                              tooltip: 'Show suggested quantities',
                              icon: const Icon(Icons.arrow_drop_down),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: _validateQuantity,
                          onFieldSubmitted: (_) => _submitForm(),
                        );
                      },
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
