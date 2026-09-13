import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/pantry_firestore_service.dart';
import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';

class MarkConsumedResult {
  const MarkConsumedResult({required this.consumed, required this.remaining});

  final double consumed;
  final double remaining;
}

/// Lets the user choose how much of a pantry item was consumed.
///
/// Writes to Firestore before closing. Returns null if cancelled or failed.
class MarkConsumedBottomSheet extends ConsumerStatefulWidget {
  const MarkConsumedBottomSheet({required this.item, super.key});

  final PantryItem item;

  static Future<MarkConsumedResult?> show(
    BuildContext context,
    PantryItem item,
  ) {
    return showModalBottomSheet<MarkConsumedResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => MarkConsumedBottomSheet(item: item),
    );
  }

  @override
  ConsumerState<MarkConsumedBottomSheet> createState() =>
      _MarkConsumedBottomSheetState();
}

class _MarkConsumedBottomSheetState
    extends ConsumerState<MarkConsumedBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _consumedController;
  late double _consumed;
  bool _isSubmitting = false;

  PantryItem get _item => widget.item;

  double get _available => _item.quantity;

  double get _remaining {
    final leftover = _available - _consumed;
    return leftover < 0 ? 0 : double.parse(leftover.toStringAsFixed(2));
  }

  bool get _canConfirm =>
      !_isSubmitting && _consumed > 0 && _consumed <= _available;

  @override
  void initState() {
    super.initState();
    final initial = _available <= 0
        ? 0.0
        : (_item.quantityStep <= _available ? _item.quantityStep : _available);
    _consumed = double.parse(initial.toStringAsFixed(2));
    _consumedController = TextEditingController(
      text: _formatQuantity(_consumed),
    );
  }

  @override
  void dispose() {
    _consumedController.dispose();
    super.dispose();
  }

  void _setConsumed(double value) {
    final clamped = value.clamp(0.0, _available);
    final rounded = double.parse(clamped.toStringAsFixed(2));
    setState(() => _consumed = rounded);
    _consumedController.value = TextEditingValue(
      text: _formatQuantity(rounded),
      selection: TextSelection.collapsed(
        offset: _formatQuantity(rounded).length,
      ),
    );
  }

  Future<void> _confirm() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_consumed <= 0 || _consumed > _available) return;

    setState(() => _isSubmitting = true);

    try {
      final remaining = await ref
          .read(pantryItemsProvider.notifier)
          .markConsumed(item: _item, consumedQuantity: _consumed);

      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(MarkConsumedResult(consumed: _consumed, remaining: remaining));
    } catch (error, stackTrace) {
      debugPrint('Mark consumed failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.statusRed,
          content: Text(mapPantryFirestoreError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _item.unit.displayLabel(_available);
    final remainingLabel =
        '${_formatQuantity(_remaining)} ${_item.unit.displayLabel(_remaining)}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mark consumed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Available: ${_item.quantityLabel}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Consumed Quantity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StepperButton(
                    icon: Icons.remove,
                    tooltip: 'Decrease consumed quantity',
                    enabled: !_isSubmitting && _consumed > 0,
                    onPressed: () =>
                        _setConsumed(_consumed - _item.quantityStep),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _consumedController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: unit,
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.cardBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGreen,
                            width: 1.8,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value.trim());
                        setState(() => _consumed = parsed ?? 0);
                      },
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null) {
                          return 'Enter a valid number.';
                        }
                        if (parsed <= 0) {
                          return 'Enter a quantity greater than 0.';
                        }
                        if (parsed > _available) {
                          return 'Only ${_item.quantityValueLabel} ${_item.unit.displayLabel(_available)} are available.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StepperButton(
                    icon: Icons.add,
                    tooltip: 'Increase consumed quantity',
                    enabled: !_isSubmitting && _consumed < _available,
                    onPressed: () =>
                        _setConsumed(_consumed + _item.quantityStep),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Remaining: $remainingLabel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _consumed > _available
                      ? AppColors.statusRed
                      : AppColors.heading,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _canConfirm ? _confirm : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Confirm Consumed'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? AppColors.primaryDark
                  : AppColors.textSecondary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
