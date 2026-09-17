import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shopping_list/data/food_item_suggestions.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_summary.dart';
import '../providers/food_waste_provider.dart';
import '../waste_feedback.dart';

class RecordWasteScreen extends ConsumerStatefulWidget {
  const RecordWasteScreen({super.key, this.initialRecord});
  final FoodWasteRecord? initialRecord;
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
  bool get _sameUser =>
      !_expired &&
      _openedUid != null &&
      _openedUid == ref.read(wasteAuthUidProvider).asData?.value &&
      ref.read(foodWasteRepositoryProvider).isCurrentUser(_openedUid!);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    _openedUid = ref.read(wasteAuthUidProvider).asData?.value;
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
      await ref
          .read(foodWasteProvider.notifier)
          .save(
            FoodWasteRecord(
              id: widget.initialRecord?.id,
              itemName: _name.text.trim(),
              quantity: double.parse(_quantity.text.trim()),
              unit: _unit,
              reason: _reason,
              estimatedValue: double.parse(_value.text.trim()),
              wastedAt: _date,
            ),
          );
      if (mounted && _sameUser) {
        _saved = true;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted && _sameUser) showWasteError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
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
                                final query = value.text.trim().toLowerCase();
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
                                        decoration: const InputDecoration(
                                          labelText: 'Item Name',
                                          prefixIcon: Icon(Icons.search),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Enter an item name.'
                                            : null,
                                      ),
                              optionsViewBuilder: (context, select, options) =>
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 3,
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width:
                                            (MediaQuery.sizeOf(context).width -
                                                    40)
                                                .clamp(0, 560)
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
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                              ),
                              validator: (value) =>
                                  _numberError(value, positive: true),
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              initialValue: _unit,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
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
                            DropdownButtonFormField<String>(
                              initialValue: _reason,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Reason',
                              ),
                              items: [
                                for (final reason in wasteReasons)
                                  DropdownMenuItem(
                                    value: reason,
                                    child: Text(reason),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _reason = value!),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              key: const ValueKey('waste-value'),
                              controller: _value,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Estimated Value',
                                prefixText: 'Rs. ',
                              ),
                              validator: _numberError,
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text('Date: ${wasteDate(_date)}'),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              key: const ValueKey('save-waste'),
                              onPressed:
                                  _saving ||
                                      _saved ||
                                      records.isLoading ||
                                      records.asData == null
                                  ? null
                                  : _save,
                              icon: _saving
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
    );
  }
}
