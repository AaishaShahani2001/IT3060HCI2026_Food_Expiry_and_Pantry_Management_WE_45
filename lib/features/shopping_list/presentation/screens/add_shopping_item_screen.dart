import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/food_item_suggestions.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/quantity_presets.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/shopping_error_message.dart';
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
    _itemNameController.addListener(_refreshFormOptions);
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

  void _pickItem(String name) {
    _itemNameController.text = name;
    _itemNameController.selection = TextSelection.collapsed(
      offset: name.length,
    );
    _itemNameFocusNode.unfocus();
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

  Future<void> _submitForm() async {
    if (_hasSubmitted || _isSubmitting) return;
    if (_formKey.currentState?.validate() ?? false) {
      final item = ShoppingItem(
        id: widget.initialItem?.id,
        name: _itemNameController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        isPurchased: widget.initialItem?.isPurchased ?? false,
      );

      FocusScope.of(context).unfocus();
      setState(() => _isSubmitting = true);
      ShoppingItem? confirmedDuplicate;
      ShoppingDuplicateAction? action;
      try {
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
              action = await _confirmDuplicate(
                duplicate.existing,
                item.quantity,
              );
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(shoppingErrorMessage(error))));
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<ShoppingDuplicateAction?> _confirmDuplicate(
    ShoppingItem existing,
    int requestedQuantity,
  ) async {
    final total = existing.quantity + requestedQuantity;
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
                ? '${existing.name} is already marked as Bought. Move it to To Buy with quantity $requestedQuantity, or add another entry?'
                : '${existing.name} is already in your shopping list with quantity ${existing.quantity}. '
                      '${total > 100 ? 'Maximum quantity is 100. You can add a separate entry or change your quantity.' : 'Increase it to $total, or add another entry?'}',
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
                onPressed: !existing.isPurchased && total > 100
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
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final quickQuantities = quantityPresetsFor(_itemNameController.text);
    final selectedQuantity = _quantityController.text.trim();
    final quantityValue = int.tryParse(selectedQuantity);
    final quickPicks = foodItemSuggestions.where(
      (name) => const {'Milk', 'Eggs', 'Bread', 'Rice'}.contains(name),
    );

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
                                          fieldViewBuilder:
                                              (
                                                context,
                                                controller,
                                                focusNode,
                                                onSubmitted,
                                              ) {
                                                return TextFormField(
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
                                    const SizedBox(height: 16),
                                    Text(
                                      'Quick Pick',
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
                                            onPressed: () => _pickItem(name),
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
