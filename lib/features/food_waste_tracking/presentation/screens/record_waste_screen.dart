import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shopping_list/data/food_item_suggestions.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_summary.dart';
import '../providers/food_waste_provider.dart';
import '../providers/pantry_waste_provider.dart';
import '../widgets/waste_motion.dart';
import '../waste_feedback.dart';

class RecordWasteScreen extends ConsumerStatefulWidget {
  const RecordWasteScreen({super.key, this.initialRecord, this.pantrySource})
    : assert(initialRecord == null || pantrySource == null);
  final FoodWasteRecord? initialRecord;
  final PantryWasteSource? pantrySource;
  @override
  ConsumerState<RecordWasteScreen> createState() => _RecordWasteScreenState();
}

class _RecordWasteScreenState extends ConsumerState<RecordWasteScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _value = TextEditingController();
  final _nameFocus = FocusNode();
  late DateTime _date;
  String _unit = wasteUnits.first;
  String _reason = wasteReasons.first;
  String? _openedUid;
  bool _expired = false;
  bool _saving = false;
  bool _saved = false;
  bool _choosingDuplicate = false;
  bool get _sameUser =>
      !_expired &&
      _openedUid != null &&
      _openedUid == ref.read(wasteAuthUidProvider).asData?.value &&
      ref.read(foodWasteRepositoryProvider).isCurrentUser(_openedUid!);

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialRecord ??
        widget.pantrySource?.draft(ref.read(wasteClockProvider)());
    _openedUid =
        widget.pantrySource?.uid ??
        ref.read(wasteAuthUidProvider).asData?.value;
    _name.text = initial?.itemName ?? '';
    _quantity.text = initial == null ? '' : wasteNumber(initial.quantity);
    _value.text = initial == null ? '0' : wasteNumber(initial.estimatedValue);
    _date = initial?.wastedAt.toLocal() ?? ref.read(wasteClockProvider)();
    _unit = initial?.unit ?? wasteUnits.first;
    _reason = initial?.reason ?? wasteReasons.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _value.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String? _numberError(String? input, {bool positive = false}) {
    final value = double.tryParse(input?.trim() ?? '');
    if (value == null ||
        !value.isFinite ||
        (positive ? value <= 0 : value < 0)) {
      return positive
          ? 'Enter a quantity greater than 0.'
          : 'Enter a value of 0 or more.';
    }
    return null;
  }

  InputDecoration _fieldDecoration(
    String label, {
    Widget? icon,
    String? prefix,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon,
      prefixText: prefix,
      filled: true,
      fillColor: colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving ||
        _saved ||
        !_sameUser ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final record = FoodWasteRecord(
        id: widget.initialRecord?.id,
        itemName: _name.text.trim(),
        quantity: double.parse(_quantity.text.trim()),
        unit: _unit,
        reason: _reason,
        estimatedValue: double.parse(_value.text.trim()),
        wastedAt: _date,
        source:
            widget.initialRecord?.source ??
            (widget.pantrySource == null ? null : 'pantry'),
        sourcePantryItemId:
            widget.initialRecord?.sourcePantryItemId ??
            widget.pantrySource?.item.firestoreId,
      );
      WasteDuplicateWarning? confirmation;
      FoodWasteRecord? saved;
      while (mounted && _sameUser) {
        try {
          saved = await ref
              .read(foodWasteProvider.notifier)
              .save(record, confirmedDuplicate: confirmation);
          break;
        } on WasteDuplicateWarning catch (warning) {
          if (!mounted || !_sameUser) return;
          setState(() => _choosingDuplicate = true);
          bool answered = false;
          final saveAnyway = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              void answer(bool value) {
                if (answered) return;
                answered = true;
                Navigator.of(dialogContext).pop(value);
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                icon: const Icon(Icons.info_outline),
                title: const Text('Similar waste record'),
                content: Text(
                  widget.pantrySource == null
                      ? 'This waste record looks similar to one already saved.'
                      : 'This expired item may already have been recorded as waste.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => answer(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => answer(true),
                    child: const Text('Save Anyway'),
                  ),
                ],
              );
            },
          );
          if (!mounted || !_sameUser || saveAnyway != true) return;
          setState(() => _choosingDuplicate = false);
          confirmation = warning;
        }
      }
      if (mounted && _sameUser && saved != null) {
        _saved = true;
        if (widget.pantrySource != null) await _offerPantryUpdate(saved);
        if (!mounted || !_sameUser) return;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted && _sameUser) showWasteError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _choosingDuplicate = false;
        });
      }
    }
  }

  Future<void> _offerPantryUpdate(FoodWasteRecord saved) async {
    final source = widget.pantrySource!;
    setState(() => _choosingDuplicate = true);
    final compatible =
        saved.unit == wasteUnitFor(source.item.unit) &&
        saved.quantity <= source.item.quantity;
    bool answered = false;
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        void answer(bool value) {
          if (answered) return;
          answered = true;
          Navigator.of(dialogContext).pop(value);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: const Icon(Icons.inventory_2_outlined),
          title: const Text('Update Pantry?'),
          content: Text(
            'Waste was saved. You recorded ${wasteNumber(saved.quantity)} ${saved.unit} of ${saved.itemName} as waste.\n\n${compatible ? 'Remove this quantity from Pantry?' : 'Quantity or unit differs from available Pantry stock. Pantry will stay unchanged.'}\n\nKeeping or cancelling here does not undo the saved Waste record.',
          ),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => answer(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => answer(false),
              child: const Text('Keep Pantry Unchanged'),
            ),
            FilledButton(
              onPressed: compatible ? () => answer(true) : null,
              child: const Text('Remove from Pantry'),
            ),
          ],
        );
      },
    );
    if (!mounted || !_sameUser || remove != true) return;
    setState(() => _choosingDuplicate = false);
    try {
      await ref
          .read(pantryWasteActionsProvider)
          .removeSavedQuantity(source, saved);
    } catch (error) {
      debugPrint('Waste Pantry update failed: $error');
      if (mounted && _sameUser) {
        showWasteMessage(
          context,
          'Waste was recorded, but Pantry could not be updated.',
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final today = ref.read(wasteClockProvider)().toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(DateTime(1900)) ? _date : DateTime(1900),
      lastDate: _date.isAfter(today) ? _date : today,
    );
    if (mounted && _sameUser && picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wasteAuthUidProvider, (previous, next) {
      if (next.asData != null &&
          _openedUid != null &&
          next.asData!.value != _openedUid) {
        _expired = true;
      }
    });
    final auth = ref.watch(wasteAuthUidProvider);
    final records = ref.watch(foodWasteProvider);
    _openedUid ??= auth.asData?.value;
    // Keep the source account's stock live while the dashboard route is paused.
    if (widget.pantrySource != null && _sameUser) {
      ref.watch(wastePantryItemsProvider(widget.pantrySource!.uid));
    }
    final editing = widget.initialRecord != null;
    return PopScope(
      canPop: !_saving || _expired,
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Edit Waste Record' : 'Record Waste'),
        ),
        body: auth.isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_sameUser
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Your account changed. Go back and reopen Waste Tracker.',
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: WasteSurface(
                      child: AnimatedSize(
                        duration: wasteMotionDuration(context),
                        alignment: Alignment.topCenter,
                        child: AbsorbPointer(
                          absorbing: _saving,
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Every record is a step toward less waste.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 24),
                                RawAutocomplete<String>(
                                  textEditingController: _name,
                                  focusNode: _nameFocus,
                                  optionsBuilder: (value) {
                                    final query = value.text
                                        .trim()
                                        .toLowerCase();
                                    return query.isEmpty
                                        ? const Iterable<String>.empty()
                                        : foodItemSuggestions
                                              .where(
                                                (name) => name
                                                    .toLowerCase()
                                                    .startsWith(query),
                                              )
                                              .take(8);
                                  },
                                  fieldViewBuilder:
                                      (context, controller, focus, submit) =>
                                          TextFormField(
                                            key: const ValueKey('waste-name'),
                                            controller: controller,
                                            focusNode: focus,
                                            decoration: _fieldDecoration(
                                              'Item Name',
                                              icon: const Icon(Icons.search),
                                            ),
                                            validator: (value) =>
                                                value == null ||
                                                    value.trim().isEmpty
                                                ? 'Enter an item name.'
                                                : null,
                                          ),
                                  optionsViewBuilder:
                                      (context, select, options) => Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 3,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: SizedBox(
                                            width:
                                                (MediaQuery.sizeOf(
                                                          context,
                                                        ).width -
                                                        72)
                                                    .clamp(0, 528)
                                                    .toDouble(),
                                            height: 220,
                                            child: ListView(
                                              padding: EdgeInsets.zero,
                                              children: [
                                                for (final option in options)
                                                  ListTile(
                                                    title: Text(option),
                                                    onTap: () => select(option),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const ValueKey('waste-quantity'),
                                  controller: _quantity,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _fieldDecoration('Quantity'),
                                  validator: (value) =>
                                      _numberError(value, positive: true),
                                ),
                                const SizedBox(height: 20),
                                DropdownButtonFormField<String>(
                                  initialValue: _unit,
                                  isExpanded: true,
                                  decoration: _fieldDecoration('Unit'),
                                  items: [
                                    for (final unit in wasteUnits)
                                      DropdownMenuItem(
                                        value: unit,
                                        child: Text(unit),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _unit = value!),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Reason',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final reason in wasteReasons)
                                      AnimatedContainer(
                                        duration: wasteMotionDuration(
                                          context,
                                          200,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _reason == reason
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primaryContainer
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Semantics(
                                          selected: _reason == reason,
                                          child: TextButton(
                                            onPressed: () => setState(
                                              () => _reason = reason,
                                            ),
                                            child: AnimatedDefaultTextStyle(
                                              duration: wasteMotionDuration(
                                                context,
                                                200,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge!
                                                  .copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                    fontWeight:
                                                        _reason == reason
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                              child: Text(reason),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const ValueKey('waste-value'),
                                  controller: _value,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _fieldDecoration(
                                    'Estimated Value',
                                    prefix: 'Rs. ',
                                  ),
                                  validator: _numberError,
                                ),
                                const SizedBox(height: 20),
                                OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                  label: Text('Date: ${wasteDate(_date)}'),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  key: const ValueKey('save-waste'),
                                  onPressed:
                                      _saving ||
                                          _saved ||
                                          records.isLoading ||
                                          records.asData == null
                                      ? null
                                      : _save,
                                  icon: _saving && !_choosingDuplicate
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check),
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      editing
                                          ? 'Update Waste Record'
                                          : 'Save Waste Record',
                                    ),
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
      ),
    );
  }
}
