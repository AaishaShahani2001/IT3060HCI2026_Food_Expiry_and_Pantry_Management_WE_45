import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/pantry_item.dart';

class PantryItemFormData {
  const PantryItemFormData({
    required this.name,
    required this.category,
    required this.location,
    required this.quantity,
    required this.unit,
    this.expiryDate,
  });

  final String name;
  final PantryCategory category;
  final PantryLocation location;
  final double quantity;
  final PantryUnit unit;
  final DateTime? expiryDate;
}

class PantryItemForm extends StatefulWidget {
  const PantryItemForm({
    required this.onSubmit,
    this.initialItem,
    this.isSaving = false,
    super.key,
  });

  final PantryItem? initialItem;
  final bool isSaving;
  final Future<void> Function(PantryItemFormData data) onSubmit;

  @override
  State<PantryItemForm> createState() => _PantryItemFormState();
}

class _PantryItemFormState extends State<PantryItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;

  late PantryCategory _category;
  late PantryLocation _location;
  late PantryUnit _unit;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: item != null
          ? (item.quantity == item.quantity.roundToDouble()
                ? item.quantity.toInt().toString()
                : item.quantity.toString())
          : '',
    );
    _category = item?.category ?? PantryCategory.other;
    _location = item?.location ?? PantryLocation.pantry;
    _unit = item?.unit ?? PantryUnit.items;
    _expiryDate = item?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
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
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primaryGreen),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final quantity = double.parse(_quantityController.text.trim());

    await widget.onSubmit(
      PantryItemFormData(
        name: _nameController.text.trim(),
        category: _category,
        location: _location,
        quantity: quantity,
        unit: _unit,
        expiryDate: _expiryDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabel('Item name'),
          TextFormField(
            controller: _nameController,
            enabled: !widget.isSaving,
            textCapitalization: TextCapitalization.sentences,
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
            value: _category,
            decoration: _inputDecoration(prefixIcon: Icons.category_outlined),
            items: PantryCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(category.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.isSaving
                ? null
                : (value) {
                    if (value != null) setState(() => _category = value);
                  },
          ),
          const SizedBox(height: 16),
          _buildLabel('Location'),
          DropdownButtonFormField<PantryLocation>(
            value: _location,
            decoration: _inputDecoration(prefixIcon: Icons.place_outlined),
            items: PantryLocation.values
                .map(
                  (location) => DropdownMenuItem(
                    value: location,
                    child: Row(
                      children: [
                        Icon(location.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(location.label),
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Quantity is required.';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null) {
                          return 'Enter a valid number.';
                        }
                        if (parsed <= 0) {
                          return 'Quantity must be greater than 0.';
                        }
                        return null;
                      },
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
                      value: _unit,
                      decoration: _inputDecoration(prefixIcon: Icons.scale),
                      items: PantryUnit.values
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                          )
                          .toList(),
                      onChanged: widget.isSaving
                          ? null
                          : (value) {
                              if (value != null) setState(() => _unit = value);
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                      ? AppColors.heading
                      : AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.isSaving ? null : _handleSubmit,
            child: widget.isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.white,
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
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.heading,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.6),
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: AppColors.primaryDark, size: 22)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.statusRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.statusRed, width: 1.8),
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
