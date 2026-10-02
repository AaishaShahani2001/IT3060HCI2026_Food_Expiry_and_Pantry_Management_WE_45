import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/utils/pantry_duplicate_lookup.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/duplicate_item_dialog.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/food_item_suggestions.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/quantity_presets.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_item_metadata.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_pantry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/shopping_error_message.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/shopping_snackbar.dart';
import 'package:go_router/go_router.dart';

class AddShoppingItemScreen extends ConsumerStatefulWidget {
  final ShoppingItem? initialItem;

  const AddShoppingItemScreen({super.key, this.initialItem});

  @override
  ConsumerState<AddShoppingItemScreen> createState() =>
      _AddShoppingItemScreenState();
}

class _AddShoppingItemScreenState extends ConsumerState<AddShoppingItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameFieldKey = GlobalKey<FormFieldState<String>>();
  late final TextEditingController _itemNameController;
  late final TextEditingController _quantityController;
  final FocusNode _itemNameFocusNode = FocusNode();
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  bool _waitingForChoice = false;
  bool _readPrefill = false;
  String? _formUid;
  bool _sessionExpired = false;
  BuildContext? _duplicateDialogContext;
  late PantryUnit _selectedUnit;
  late String _selectedCategory;
  late bool _unitManuallySelected;
  late bool _categoryManuallySelected;
  bool _applyingSelectedItem = false;
  String? _selectedCatalogName;
  String? _confirmedPantryName;

  bool get _sameUser =>
      !_sessionExpired &&
      _formUid != null &&
      _formUid == ref.read(shoppingAuthUidProvider).asData?.value;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    _formUid = ref.read(shoppingAuthUidProvider).asData?.value;
    _itemNameController = TextEditingController(
      text: widget.initialItem?.name ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.initialItem?.quantity.toString() ?? '',
    );
    _selectedUnit = widget.initialItem?.unit ?? PantryUnit.items;
    _selectedCategory = widget.initialItem?.category ?? 'Other';
    _unitManuallySelected = _isEditing;
    _categoryManuallySelected = _isEditing;
    _itemNameController.addListener(_onNameChanged);
    _quantityController.addListener(_refreshFormOptions);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readPrefill) {
      _readPrefill = true;
      if (!_isEditing) {
        _itemNameController.text =
            GoRouterState.of(context).uri.queryParameters['name'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _itemNameController.removeListener(_onNameChanged);
    _quantityController.removeListener(_refreshFormOptions);
    _itemNameController.dispose();
    _quantityController.dispose();
    _itemNameFocusNode.dispose();
    super.dispose();
  }

  void _refreshFormOptions() {
    setState(() {});
  }

  void _onNameChanged() {
    _confirmedPantryName = null;
    if (!_applyingSelectedItem) {
      _selectedCatalogName = null;
      _refreshFormOptions();
    }
  }

  void _setQuantity(int quantity) {
    _quantityController.text = quantity.toString();
    _quantityController.selection = TextSelection.collapsed(
      offset: _quantityController.text.length,
    );
  }

  void _applySelectedShoppingItem(String name) {
    final canonicalName = canonicalFoodItemNameFor(name) ?? name.trim();
    final category = foodItemCategoryFor(canonicalName);
    final unit = shoppingDefaultUnitForFood(canonicalName);

    _applyingSelectedItem = true;
    _itemNameController.value = TextEditingValue(
      text: canonicalName,
      selection: TextSelection.collapsed(offset: canonicalName.length),
    );
    final itemNameField = _itemNameFieldKey.currentState;
    itemNameField?.didChange(canonicalName);
    itemNameField?.validate();
    _applyingSelectedItem = false;

    setState(() {
      _selectedCategory = category;
      _selectedUnit = unit ?? PantryUnit.items;
      _categoryManuallySelected = false;
      _unitManuallySelected = false;
      _selectedCatalogName = normalizeFoodItemName(canonicalName);
    });
    _itemNameFocusNode.unfocus();
  }

  Iterable<String> _findFoodSuggestions(TextEditingValue textEditingValue) {
    final query = textEditingValue.text.trim().toLowerCase();

    if (query.isEmpty) {
      return const Iterable<String>.empty();
    }

    return matchFoodItemSuggestions(query);
  }

  PantryItem? _matchingPantryItem() {
    final items =
        ref.read(shoppingPantryItemsProvider).asData?.value ?? const [];
    return lookupDuplicatePantryItemByName(items, _itemNameController.text);
  }

  String _effectiveCategory(PantryItem? pantryMatch) {
    if (_categoryManuallySelected) return _selectedCategory;
    if (_selectedCatalogName ==
        normalizeFoodItemName(_itemNameController.text)) {
      return _selectedCategory;
    }
    if (pantryMatch != null) return shoppingCategoryForPantryItem(pantryMatch);
    return foodItemCategoryFor(_itemNameController.text);
  }

  PantryUnit _effectiveUnit(PantryItem? pantryMatch) {
    if (_unitManuallySelected) return _selectedUnit;
    if (_selectedCatalogName ==
        normalizeFoodItemName(_itemNameController.text)) {
      return _selectedUnit;
    }
    return pantryMatch?.unit ?? PantryUnit.items;
  }

  Future<void> _submitForm() async {
    if (_hasSubmitted || _isSubmitting) return;
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      setState(() => _isSubmitting = true);
      ShoppingItem? confirmedDuplicate;
      ShoppingDuplicateAction? action;
      try {
        final pantryMatch = _matchingPantryItem();
        final normalizedName = _itemNameController.text.trim().toLowerCase();
        if (!_isEditing &&
            pantryMatch != null &&
            _confirmedPantryName != normalizedName) {
          setState(() => _waitingForChoice = true);
          final addAnyway = await showPantryPresenceWarning(
            context: context,
            existingItem: pantryMatch,
          );
          if (mounted) setState(() => _waitingForChoice = false);
          if (!addAnyway || !mounted || !_sameUser) return;
          _confirmedPantryName = normalizedName;
        }
        final item = ShoppingItem(
          id: widget.initialItem?.id,
          name: _itemNameController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
          isPurchased: widget.initialItem?.isPurchased ?? false,
          unit: _effectiveUnit(pantryMatch),
          category: _effectiveCategory(pantryMatch),
          source: widget.initialItem?.source,
          sourcePantryItemId: widget.initialItem?.sourcePantryItemId,
        );
        // Stay on the form until persistence succeeds; Cancel keeps the draft.
        while (mounted) {
          if (!_sameUser) throw StateError('Account changed');
          try {
            final notifier = ref.read(shoppingListProvider.notifier);
            final saved = _isEditing
                ? await notifier.saveEditedItem(
                    item,
                    confirmedDuplicate: confirmedDuplicate,
                  )
                : await notifier.addItem(
                    item,
                    duplicateAction: action,
                    confirmedDuplicate: confirmedDuplicate,
                  );
            if (mounted && _sameUser) {
              _hasSubmitted = true;
              context.pop(saved);
            }
            return;
          } on ShoppingDuplicateException catch (duplicate) {
            if (!mounted || !_sameUser) return;
            setState(() => _waitingForChoice = true);
            try {
              action = await _confirmDuplicate(duplicate.existing, item);
            } finally {
              if (mounted) setState(() => _waitingForChoice = false);
            }
            if (action == null || !mounted) return;
            confirmedDuplicate = duplicate.existing;
          }
        }
      } catch (error) {
        if (mounted && _sameUser) {
          debugPrint('Shopping form error: $error');
          ShoppingSnackBar.show(
            context,
            message: shoppingErrorMessage(error),
            duration: ShoppingSnackBar.error,
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<ShoppingDuplicateAction?> _confirmDuplicate(
    ShoppingItem existing,
    ShoppingItem requested,
  ) async {
    final total = existing.quantity + requested.quantity;
    final sameUnit = existing.unit == requested.unit;
    bool resolved = false;
    void choose(BuildContext dialogContext, ShoppingDuplicateAction? action) {
      if (resolved) return;
      resolved = true;
      Navigator.of(dialogContext).pop(action);
    }

    final result = await showDialog<ShoppingDuplicateAction>(
      context: context,
      builder: (dialogContext) {
        _duplicateDialogContext = dialogContext;
        return AlertDialog(
          scrollable: true,
          title: Text(
            _isEditing
                ? 'This item name already exists'
                : existing.isPurchased
                ? 'Already bought'
                : 'Already on your list',
          ),
          content: Text(
            _isEditing
                ? '${existing.name} is already in your shopping list. Save this as a separate entry?'
                : existing.isPurchased
                ? '${existing.name} is already marked as Bought. Move it to To Buy with quantity ${requested.quantity} ${shoppingUnitLabel(requested.unit)}, or add another entry?'
                : '${existing.name} is already in your shopping list with quantity ${existing.quantity} ${shoppingUnitLabel(existing.unit)}. '
                      '${!sameUnit
                          ? 'The units differ, so add a separate entry or change the unit.'
                          : total > 100
                          ? 'Maximum quantity is 100. You can add a separate entry or change your quantity.'
                          : 'Increase it to $total ${shoppingUnitLabel(existing.unit)}, or add another entry?'}',
          ),
          actions: [
            TextButton(
              onPressed: () => choose(dialogContext, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  choose(dialogContext, ShoppingDuplicateAction.addAnyway),
              child: Text(_isEditing ? 'Save Anyway' : 'Add Anyway'),
            ),
            if (!_isEditing)
              FilledButton(
                onPressed: !existing.isPurchased && (!sameUnit || total > 100)
                    ? null
                    : () => choose(
                        dialogContext,
                        existing.isPurchased
                            ? ShoppingDuplicateAction.moveToBuy
                            : ShoppingDuplicateAction.increaseQuantity,
                      ),
                child: Text(
                  existing.isPurchased
                      ? 'Move to To Buy'
                      : 'Increase to $total',
                ),
              ),
          ],
        );
      },
    );
    _duplicateDialogContext = null;
    return result;
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
    ref.listen(shoppingAuthUidProvider, (previous, next) {
      if (next.asData != null &&
          _formUid != null &&
          next.asData!.value != _formUid) {
        _sessionExpired = true;
        final dialog = _duplicateDialogContext;
        _duplicateDialogContext = null;
        if (dialog != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialog.mounted && ModalRoute.of(dialog)?.isCurrent == true) {
              Navigator.of(dialog).pop();
            }
          });
        }
      }
    });
    final auth = ref.watch(shoppingAuthUidProvider);
    _formUid ??= auth.asData?.value;
    final shopping = ref.watch(shoppingListProvider);
    final pantry = ref.watch(shoppingPantryItemsProvider);
    final pantryMatch = lookupDuplicatePantryItemByName(
      pantry.asData?.value ?? const <PantryItem>[],
      _itemNameController.text,
    );
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final quickQuantities = quantityPresetsFor(_itemNameController.text);
    final selectedQuantity = _quantityController.text.trim();
    final quantityValue = int.tryParse(selectedQuantity);
    final quickPicks = shoppingQuickPicks(
      shopping.asData?.value ?? const <ShoppingItem>[],
    );
    final effectiveCategory = _effectiveCategory(pantryMatch);
    final effectiveUnit = _effectiveUnit(pantryMatch);
    final categoryOptions = <String>{
      ...foodItemSuggestionCategories.keys,
      effectiveCategory,
      'Other',
    }.toList();
    final unitOptions = <PantryUnit>{...shoppingUnits, effectiveUnit}.toList();

    return PopScope(
      canPop: !_isSubmitting || _sessionExpired,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? AppStrings.editShoppingItemTitle
                : 'Add To Shopping List',
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 20,
              color: colors.onSurface,
            ),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: false,
        ),
        body: SafeArea(
          child: _sessionExpired
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your account changed. Go back and reopen your shopping list.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : auth.isLoading
              ? const Center(child: CircularProgressIndicator())
              : auth.asData?.value == null
              ? const Center(
                  child: Text('Please sign in to use your shopping list.'),
                )
              : AbsorbPointer(
                  absorbing: _isSubmitting,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: colors.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return RawAutocomplete<String>(
                                          textEditingController:
                                              _itemNameController,
                                          focusNode: _itemNameFocusNode,
                                          optionsBuilder: _findFoodSuggestions,
                                          onSelected:
                                              _applySelectedShoppingItem,
                                          fieldViewBuilder:
                                              (
                                                context,
                                                controller,
                                                focusNode,
                                                onSubmitted,
                                              ) {
                                                return TextFormField(
                                                  key: _itemNameFieldKey,
                                                  controller: controller,
                                                  focusNode: focusNode,
                                                  autofocus: true,
                                                  textCapitalization:
                                                      TextCapitalization
                                                          .sentences,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        AppStrings.itemName,
                                                    hintText:
                                                        AppStrings.itemNameHint,
                                                    prefixIcon: const Icon(
                                                      Icons.search,
                                                    ),
                                                    suffixIcon:
                                                        _itemNameController
                                                            .text
                                                            .isEmpty
                                                        ? null
                                                        : IconButton(
                                                            tooltip:
                                                                'Clear item name',
                                                            onPressed:
                                                                _itemNameController
                                                                    .clear,
                                                            icon: const Icon(
                                                              Icons
                                                                  .cancel_outlined,
                                                            ),
                                                          ),
                                                    filled: true,
                                                    fillColor: colors
                                                        .secondaryContainer
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                  ),
                                                  validator: _validateItemName,
                                                  onFieldSubmitted: (_) =>
                                                      onSubmitted(),
                                                );
                                              },
                                          optionsViewBuilder: (context, onSelected, options) {
                                            final matches = options.toList();

                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                color: colors
                                                    .surfaceContainerHighest,
                                                elevation: 4,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: SizedBox(
                                                  width: constraints.maxWidth,
                                                  child: ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxHeight: 240,
                                                        ),
                                                    child: ListView.builder(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      shrinkWrap: true,
                                                      itemCount: matches.length,
                                                      itemBuilder: (context, index) {
                                                        final item =
                                                            matches[index];
                                                        final isHighlighted =
                                                            AutocompleteHighlightedOption.of(
                                                              context,
                                                            ) ==
                                                            index;

                                                        return InkWell(
                                                          onTap: () =>
                                                              onSelected(item),
                                                          child: Container(
                                                            color: isHighlighted
                                                                ? colors
                                                                      .secondaryContainer
                                                                : null,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 14,
                                                                ),
                                                            child: Text(
                                                              item,
                                                              style: textTheme
                                                                  .bodyLarge
                                                                  ?.copyWith(
                                                                    color: colors
                                                                        .onSurface,
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
                                    if (pantryMatch != null) ...[
                                      const SizedBox(height: 12),
                                      Semantics(
                                        label:
                                            '${pantryMatch.name} is already in your pantry with ${pantryMatch.quantityLabel}',
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: colors.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.inventory_2_outlined,
                                                color: colors.primary,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '${pantryMatch.quantityLabel} remaining in pantry',
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                        color: colors.onSurface,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Text(
                                      'Recent & frequent picks',
                                      style: textTheme.titleSmall?.copyWith(
                                        color: colors.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        for (final name in quickPicks)
                                          ActionChip(
                                            label: Text(name),
                                            onPressed: () =>
                                                _applySelectedShoppingItem(
                                                  name,
                                                ),
                                            backgroundColor: colors
                                                .secondaryContainer
                                                .withValues(alpha: 0.45),
                                            side: BorderSide.none,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Quick Quantity',
                                      style: textTheme.titleSmall?.copyWith(
                                        color: colors.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: quickQuantities.map((quantity) {
                                        final isSelected =
                                            selectedQuantity ==
                                            quantity.toString();

                                        return ChoiceChip(
                                          label: Text(quantity.toString()),
                                          selected: isSelected,
                                          showCheckmark: false,
                                          selectedColor:
                                              colors.secondaryContainer,
                                          side: BorderSide(
                                            color: isSelected
                                                ? colors.primary
                                                : colors.outline,
                                          ),
                                          labelStyle: textTheme.bodyMedium
                                              ?.copyWith(
                                                color: isSelected
                                                    ? colors.onSurface
                                                    : colors.onSurfaceVariant,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                          onSelected: (_) =>
                                              _setQuantity(quantity),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                    MenuAnchor(
                                      alignmentOffset: const Offset(0, 4),
                                      menuChildren: quantityDropdownOptions.map(
                                        (quantity) {
                                          return MenuItemButton(
                                            onPressed: () =>
                                                _setQuantity(quantity),
                                            child: SizedBox(
                                              width: 160,
                                              child: Text(quantity.toString()),
                                            ),
                                          );
                                        },
                                      ).toList(),
                                      builder: (context, menuController, child) {
                                        return TextFormField(
                                          controller: _quantityController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          textInputAction: TextInputAction.done,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          decoration: InputDecoration(
                                            labelText: AppStrings.quantity,
                                            hintText: AppStrings.quantityHint,
                                            prefixIcon: IconButton(
                                              tooltip: 'Decrease item quantity',
                                              onPressed:
                                                  quantityValue != null &&
                                                      quantityValue > 1 &&
                                                      quantityValue <= 100
                                                  ? () => _setQuantity(
                                                      quantityValue - 1,
                                                    )
                                                  : null,
                                              icon: const Icon(Icons.remove),
                                            ),
                                            suffixIcon: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () {
                                                    if (menuController.isOpen) {
                                                      menuController.close();
                                                    } else {
                                                      menuController.open();
                                                    }
                                                  },
                                                  tooltip:
                                                      'Show suggested quantities',
                                                  icon: const Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Increase item quantity',
                                                  onPressed:
                                                      quantityValue == null ||
                                                          quantityValue < 1 ||
                                                          quantityValue >= 100
                                                      ? null
                                                      : () => _setQuantity(
                                                          quantityValue + 1,
                                                        ),
                                                  icon: const Icon(Icons.add),
                                                ),
                                              ],
                                            ),
                                            filled: true,
                                            fillColor: colors.secondaryContainer
                                                .withValues(alpha: 0.35),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 16,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          validator: _validateQuantity,
                                          onFieldSubmitted: (_) =>
                                              _submitForm(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<PantryUnit>(
                                      key: ValueKey(effectiveUnit),
                                      initialValue: effectiveUnit,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Unit',
                                        prefixIcon: Icon(
                                          Icons.straighten_outlined,
                                        ),
                                      ),
                                      items: [
                                        for (final unit in unitOptions)
                                          DropdownMenuItem(
                                            value: unit,
                                            child: Text(
                                              shoppingUnitLabel(unit),
                                            ),
                                          ),
                                      ],
                                      onChanged: (unit) {
                                        if (unit == null) return;
                                        setState(() {
                                          _selectedUnit = unit;
                                          _unitManuallySelected = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(effectiveCategory),
                                      initialValue: effectiveCategory,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Category',
                                        prefixIcon: Icon(
                                          Icons.category_outlined,
                                        ),
                                      ),
                                      items: [
                                        for (final category in categoryOptions)
                                          DropdownMenuItem(
                                            value: category,
                                            child: Text(
                                              category,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (category) {
                                        if (category == null) return;
                                        setState(() {
                                          _selectedCategory = category;
                                          _categoryManuallySelected = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              FilledButton.icon(
                                onPressed:
                                    _isSubmitting ||
                                        _hasSubmitted ||
                                        shopping.isLoading ||
                                        shopping.asData == null
                                    ? null
                                    : _submitForm,
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                ),
                                icon: _isSubmitting && !_waitingForChoice
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _isEditing
                                            ? Icons.check
                                            : Icons.add_shopping_cart,
                                      ),
                                label: Text(
                                  _isEditing
                                      ? AppStrings.updateItem
                                      : AppStrings.addItem,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
