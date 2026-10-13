import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/local/pantry_food_catalog.dart';
import '../../data/services/cloudinary_config.dart';
import '../../domain/models/pantry_food_suggestion.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/utils/pantry_image_url.dart';
import '../../domain/utils/pantry_price_display.dart';
import '../utils/pantry_snackbar.dart';
import 'pantry_item_autocomplete_field.dart';
import 'pantry_item_photo_field.dart';

class PantryItemFormData {
  const PantryItemFormData({
    required this.name,
    required this.category,
    required this.location,
    required this.quantity,
    required this.originalQuantity,
    required this.unit,
    required this.price,
    required this.priceType,
    this.expiryDate,
    this.selectedPhoto,
    this.removeExistingPhoto = false,
  });

  final String name;
  final PantryCategory category;
  final PantryLocation location;
  final double quantity;
  final double originalQuantity;
  final PantryUnit unit;
  final double price;
  final PantryPriceType priceType;
  final DateTime? expiryDate;

  /// Local file chosen in this session. Not uploaded until Save.
  final XFile? selectedPhoto;

  /// True when the user removed an existing photo and did not pick a
  /// replacement. Save then clears the Firestore photo fields.
  final bool removeExistingPhoto;
}

class PantryItemFormPrefill {
  const PantryItemFormPrefill({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  final String name;
  final double quantity;
  final PantryUnit unit;
  final PantryCategory category;
}

class PantryItemForm extends StatefulWidget {
  const PantryItemForm({
    required this.onSubmit,
    this.initialItem,
    this.prefill,
    this.existingItems = const [],
    this.isSaving = false,
    this.savingMessage,
    super.key,
  });

  final PantryItem? initialItem;
  final PantryItemFormPrefill? prefill;

  /// Pantry rows already loaded for this user. Used only to suggest names.
  final List<PantryItem> existingItems;
  final bool isSaving;
  final String? savingMessage;
  final Future<void> Function(PantryItemFormData data) onSubmit;

  @override
  State<PantryItemForm> createState() => _PantryItemFormState();
}

class _PantryItemFormState extends State<PantryItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;

  PantryCategory? _category;
  late PantryLocation _location;
  late PantryUnit _unit;
  late PantryPriceType _priceType;

  /// Widget-local. Once the user picks a price type, unit changes must not
  /// replace it. Editing an item starts as already chosen.
  bool _priceTypeManuallyChosen = false;
  bool _updateOriginalQuantity = false;

  /// True after the user picks a category from the dropdown. Later edits to
  /// the same name must not replace that choice. Selecting a suggestion may.
  bool _categoryWasManuallyChanged = false;

  /// True when the current category came from a suggestion or exact name.
  bool _categorySuggested = false;
  DateTime? _expiryDate;
  XFile? _selectedPhoto;
  Uint8List? _previewBytes;
  bool _removeExistingPhoto = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    final prefill = widget.prefill;
    _nameController = TextEditingController(
      text: item?.name ?? prefill?.name ?? '',
    );
    _quantityController = TextEditingController(
      text: item != null
          ? _decimalFieldText(item.quantity)
          : prefill != null
          ? _decimalFieldText(prefill.quantity)
          : '',
    );
    _priceController = TextEditingController(
      text: item != null && item.hasPrice
          ? _decimalFieldText(item.priceAmount!)
          : '',
    );
    // Existing and Shopping List-prefilled items retain their valid category.
    // A normal new item stays unselected until the user chooses a category or
    // an exact food-name match supplies one.
    _category = item?.category ?? prefill?.category;
    // Treat a Shopping List category as an intentional initial value so name
    // edits do not replace it. Explicitly selecting an autocomplete suggestion
    // can still replace it through _handleSuggestionSelected.
    _categoryWasManuallyChanged = item == null && prefill != null;
    _location = item?.location ?? PantryLocation.pantry;
    _unit = item?.unit ?? prefill?.unit ?? PantryUnit.items;
    _priceType = item?.priceType ?? PantryPriceType.suggestedFor(_unit);
    _priceTypeManuallyChosen = item != null;
    _expiryDate = item?.expiryDate;
    _quantityController.addListener(_onPriceInputsChanged);
    _priceController.addListener(_onPriceInputsChanged);
  }

  void _onPriceInputsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onPriceInputsChanged);
    _priceController.removeListener(_onPriceInputsChanged);
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  static String _decimalFieldText(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  double? get _enteredPrice {
    final parsed = double.tryParse(_priceController.text.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed;
  }

  bool get _showOriginalQuantityNote {
    final item = widget.initialItem;
    if (item == null) return false;
    final entered = double.tryParse(_quantityController.text.trim());
    if (entered == null || !entered.isFinite) return false;
    return (entered - item.originalQuantity).abs() > 0.001;
  }

  String get _savedOriginalLabel =>
      widget.initialItem?.originalQuantityLabel ?? '';

  /// Draft used only for the live value preview. Hidden when inputs are invalid.
  PantryItem? get _valuePreview {
    final quantity = double.tryParse(_quantityController.text.trim());
    final price = _enteredPrice;
    if (quantity == null || !quantity.isFinite || quantity <= 0) return null;
    if (price == null || price <= 0) return null;

    final savedOriginal = widget.initialItem?.originalQuantity;
    final originalQuantity = widget.initialItem == null
        ? quantity
        : (_updateOriginalQuantity ? quantity : savedOriginal ?? quantity);

    return PantryItem(
      id: 'preview',
      name: 'preview',
      category: _category ?? PantryCategory.other,
      location: _location,
      quantity: quantity,
      originalQuantity: originalQuantity,
      unit: _unit,
      priceAmount: price,
      priceType: _priceType,
    );
  }

  ButtonStyle _priceTypeStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      visualDensity: VisualDensity.standard,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isDark
              ? FreshPalette.darkAccentSurface
              : FreshPalette.accentSurface;
        }
        return isDark ? FreshPalette.darkCard : FreshPalette.card;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isDark ? FreshPalette.highlight : FreshPalette.primaryButton;
        }
        return isDark
            ? FreshPalette.darkSecondaryText
            : FreshPalette.secondaryText;
      }),
      side: WidgetStatePropertyAll(
        BorderSide(
          color: isDark ? FreshPalette.darkOutline : FreshPalette.outline,
        ),
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'Select expiry date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: Theme.of(context).colorScheme),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  /// Fills the category only for a selected suggestion or an exact catalogue
  /// name. A partial value such as "ch" is ignored because it could be
  /// Cheese, Chicken or Chickpeas.
  void _handleNameEdited(String rawName) {
    if (_categoryWasManuallyChanged) return;

    final match = exactPantryFoodMatch(rawName);
    if (match == null) {
      if (_categorySuggested) {
        setState(() => _categorySuggested = false);
      }
      return;
    }
    if (_category == match.category && _categorySuggested) return;

    setState(() {
      _category = match.category;
      _categorySuggested = true;
    });
  }

  void _handleSuggestionSelected(PantryFoodSuggestion suggestion) {
    // A deliberate pick may replace a category the user chose earlier.
    _categoryWasManuallyChanged = false;
    setState(() {
      _category = suggestion.category;
      _categorySuggested = true;
    });
  }

  Future<void> _handleSubmit() async {
    if (widget.isSaving || _submitting) return;
    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final category = _category;

    if (category == null ||
        quantity == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        price == null ||
        !price.isFinite ||
        price < 0) {
      _formKey.currentState?.validate();
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final savedOriginal = widget.initialItem?.originalQuantity;
    final originalQuantity = widget.initialItem == null
        ? quantity
        : (_updateOriginalQuantity ? quantity : savedOriginal ?? quantity);

    try {
      await widget.onSubmit(
        PantryItemFormData(
          name: _nameController.text.trim(),
          category: category,
          location: _location,
          quantity: quantity,
          originalQuantity: originalQuantity,
          unit: _unit,
          price: price,
          priceType: _priceType,
          expiryDate: _expiryDate,
          selectedPhoto: _selectedPhoto,
          removeExistingPhoto: _removeExistingPhoto,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _hasPhotoPreview {
    if (_previewBytes != null) return true;
    final existingUrl = widget.initialItem?.photoUrl;
    return !_removeExistingPhoto &&
        existingUrl != null &&
        existingUrl.trim().isNotEmpty;
  }

  Widget? get _photoPreview {
    final fallbackCategory = _category ?? PantryCategory.other;
    if (_previewBytes != null) {
      return Image.memory(
        _previewBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: 'Selected item photo',
      );
    }
    final existingUrl = widget.initialItem?.photoUrl;
    if (!_removeExistingPhoto &&
        existingUrl != null &&
        existingUrl.trim().isNotEmpty) {
      return Image.network(
        pantryDisplayImageUrl(
          existingUrl,
          delivery: PantryImageDelivery.details,
        ),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: 'Selected item photo',
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(
              fallbackCategory.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      );
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    if (widget.isSaving) return;
    final source = await showPantryPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (picked == null || !mounted) return;

      final name = picked.name.toLowerCase();
      final path = picked.path.toLowerCase();
      const allowed = {'jpg', 'jpeg', 'png', 'webp'};
      final extension = _fileExtension(name.isNotEmpty ? name : path);
      if (extension != null && !allowed.contains(extension)) {
        PantrySnackBar.error(context, kPantryImageTypeMessage);
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.length > kPantryImageMaxBytes) {
        PantrySnackBar.error(context, kPantryImageTooLargeMessage);
        return;
      }

      setState(() {
        _selectedPhoto = picked;
        _previewBytes = bytes;
        _removeExistingPhoto = false;
      });
    } catch (error) {
      debugPrint('Pantry photo pick failed: $error');
      if (!mounted) return;
      PantrySnackBar.error(
        context,
        'Unable to open that photo. Please try another image.',
      );
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedPhoto = null;
      _previewBytes = null;
      _removeExistingPhoto = widget.initialItem?.hasUserPhoto == true;
    });
  }

  static String? _fileExtension(String value) {
    final dot = value.lastIndexOf('.');
    if (dot < 0 || dot == value.length - 1) return null;
    return value.substring(dot + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PantryItemPhotoField(
            category: _category ?? PantryCategory.other,
            hasPreview: _hasPhotoPreview,
            preview: _photoPreview,
            enabled: !widget.isSaving,
            onAddPhoto: _pickPhoto,
            onChangePhoto: _pickPhoto,
            onRemovePhoto: _removePhoto,
          ),
          const SizedBox(height: 20),
          _buildLabel('Item name'),
          PantryItemAutocompleteField(
            controller: _nameController,
            enabled: !widget.isSaving,
            existingItems: widget.existingItems,
            onSuggestionSelected: _handleSuggestionSelected,
            onNameEdited: _handleNameEdited,
            decoration: _inputDecoration(
              hint: 'e.g. Milk, Rice, Apples',
              prefixIcon: Icons.inventory_2_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Item name is required.';
              }
              if (value.trim().length < 2) {
                return 'Item name must be at least 2 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildLabel('Category'),
          DropdownButtonFormField<PantryCategory>(
            initialValue: _category,
            isExpanded: true,
            hint: Text(
              'Select category',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            dropdownColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            decoration: _inputDecoration(prefixIcon: Icons.category_outlined),
            items: PantryCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            category.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            validator: (value) {
              if (value == null) return 'Category is required.';
              return null;
            },
            onChanged: widget.isSaving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _category = value;
                      _categoryWasManuallyChanged = true;
                      _categorySuggested = false;
                    });
                  },
          ),
          if (_categorySuggested) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Category suggested from item name',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildLabel('Location'),
          DropdownButtonFormField<PantryLocation>(
            initialValue: _location,
            isExpanded: true,
            dropdownColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            decoration: _inputDecoration(prefixIcon: Icons.place_outlined),
            items: PantryLocation.values
                .map(
                  (location) => DropdownMenuItem(
                    value: location,
                    child: Row(
                      children: [
                        Icon(location.icon, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            location.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.isSaving
                ? null
                : (value) {
                    if (value != null) setState(() => _location = value);
                  },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Quantity'),
                    TextFormField(
                      key: const ValueKey('pantry-quantity-field'),
                      controller: _quantityController,
                      enabled: !widget.isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: _inputDecoration(
                        hint: '0',
                        prefixIcon: Icons.numbers,
                      ),
                      validator: validatePantryQuantity,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Unit'),
                    DropdownButtonFormField<PantryUnit>(
                      key: const ValueKey('pantry-unit-dropdown'),
                      initialValue: _unit,
                      isExpanded: true,
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      decoration: _inputDecoration().copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      items: PantryUnit.values
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(
                                unit.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.isSaving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _unit = value;
                                if (!_priceTypeManuallyChosen) {
                                  _priceType = PantryPriceType.suggestedFor(
                                    value,
                                  );
                                }
                              });
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showOriginalQuantityNote) ...[
            const SizedBox(height: 8),
            Text(
              'Original quantity: $_savedOriginalLabel',
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (widget.initialItem != null) ...[
            const SizedBox(height: 4),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: _updateOriginalQuantity,
                onChanged: widget.isSaving
                    ? null
                    : (value) {
                        setState(
                          () => _updateOriginalQuantity = value ?? false,
                        );
                      },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Update original quantity too'),
                subtitle: const Text(
                  'Use this only to correct the amount you first entered. Leave it off to keep the original quantity.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildLabel('Price type'),
          Semantics(
            label: '${_priceType.label}. ${_priceType.explanation}',
            child: SegmentedButton<PantryPriceType>(
              key: const ValueKey('pantry-price-type'),
              segments: [
                for (final type in PantryPriceType.values)
                  ButtonSegment<PantryPriceType>(
                    value: type,
                    label: Text(type.label),
                    tooltip: type.explanation,
                  ),
              ],
              selected: {_priceType},
              showSelectedIcon: true,
              style: _priceTypeStyle(context),
              onSelectionChanged: widget.isSaving
                  ? null
                  : (selection) {
                      setState(() {
                        _priceType = selection.first;
                        _priceTypeManuallyChosen = true;
                      });
                    },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _priceType.explanation,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel(priceEntryLabel(_unit, _priceType)),
          TextFormField(
            key: const ValueKey('pantry-price-field'),
            controller: _priceController,
            enabled: !widget.isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hint: '0.00',
              prefixText: 'Rs. ',
              helperText: priceEntryHelper(
                _unit,
                _priceType,
                amount: _enteredPrice,
              ),
            ),
            validator: (value) =>
                validatePantryPrice(value, unit: _unit, type: _priceType),
          ),
          if (_valuePreview case final preview?) ...[
            const SizedBox(height: 8),
            Text(
              'Estimated current value: ${formatPantryRupees(preview.estimatedRemainingValue)}',
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (preview.priceType == PantryPriceType.totalPrice) ...[
              const SizedBox(height: 2),
              Text(
                totalPriceShareNote(preview),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          _buildLabel('Expiry date (optional)'),
          InkWell(
            onTap: widget.isSaving ? null : _pickExpiryDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: _inputDecoration(
                prefixIcon: Icons.event_outlined,
                suffixIcon: _expiryDate != null
                    ? IconButton(
                        onPressed: widget.isSaving
                            ? null
                            : () => setState(() => _expiryDate = null),
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear expiry date',
                      )
                    : null,
              ),
              child: Text(
                _expiryDate != null
                    ? _formatDate(_expiryDate!)
                    : 'No expiry date set',
                style: TextStyle(
                  color: _expiryDate != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.isSaving || _submitting ? null : _handleSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: widget.isSaving || _submitting
                ? Semantics(
                    liveRegion: true,
                    label: widget.savingMessage ?? 'Saving item…',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        if (widget.savingMessage != null) ...[
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.savingMessage!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : Text(
                    widget.initialItem == null ? 'Save item' : 'Update item',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    IconData? prefixIcon,
    Widget? prefix,
    String? prefixText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      helperText: helperText,
      helperMaxLines: 3,
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      prefix: prefix,
      prefixText: prefixText,
      prefixStyle: prefixText != null
          ? TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            )
          : null,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: colorScheme.primary, size: 22)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error, width: 1.8),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
