import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shopping_list/data/food_item_suggestions.dart';
import '../../../pantry/data/services/pantry_firestore_service.dart';
import '../../models/automatic_waste_candidate.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_scope.dart';
import '../../models/waste_summary.dart';
import '../providers/food_waste_provider.dart';
import '../providers/pantry_waste_provider.dart';
import '../widgets/waste_motion.dart';
import '../waste_feedback.dart';

enum WasteEntrySource { storage, external }

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
  final _storageSearch = TextEditingController();
  final _storageFocus = FocusNode();
  late DateTime _date;
  String _unit = wasteUnits.first;
  String _reason = wasteReasons.first;
  late WasteEntrySource _entrySource;
  PantryWasteSource? _selectedStorage;
  WasteScope? _openedScope;
  bool _expired = false;
  bool _saving = false;
  bool _saved = false;
  bool _choosingDuplicate = false;
  bool get _sameScope =>
      !_expired &&
      _openedScope != null &&
      _openedScope == ref.read(wasteScopeProvider).asData?.value &&
      ref.read(foodWasteRepositoryProvider).isCurrentScope(_openedScope!);

  String get _scopeChangedMessage {
    final currentUid = ref.read(wasteAuthUidProvider).asData?.value;
    if (_openedScope?.actorUid != currentUid) {
      return 'Your account changed. Go back and reopen Waste Tracker.';
    }
    return 'Your pantry context changed. Go back and reopen Waste Tracker.';
  }

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialRecord ??
        widget.pantrySource?.draft(ref.read(wasteClockProvider)());
    _openedScope =
        widget.pantrySource?.scope ??
        ref.read(wasteScopeProvider).asData?.value;
    _entrySource = widget.pantrySource == null
        ? WasteEntrySource.external
        : WasteEntrySource.storage;
    _selectedStorage = widget.pantrySource;
    _name.text = initial?.itemName ?? '';
    _storageSearch.text = widget.pantrySource?.item.name ?? '';
    _quantity.text = widget.pantrySource == null
        ? (initial == null ? '' : wasteNumber(initial.quantity))
        : '';
    _value.text = initial == null ? '0' : wasteNumber(initial.estimatedValue);
    _date = initial?.wastedAt.toLocal() ?? ref.read(wasteClockProvider)();
    _unit = initial?.unit ?? wasteUnits.first;
    _reason = initial?.reason ?? wasteReasons.first;
    _storageFocus.addListener(_handleStorageFocusChange);
    _quantity.addListener(_refreshStorageValue);
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _value.dispose();
    _nameFocus.dispose();
    _storageSearch.dispose();
    _storageFocus.dispose();
    super.dispose();
  }

  bool get _newRecord => widget.initialRecord == null;
  bool get _storageMode =>
      _newRecord && _entrySource == WasteEntrySource.storage;

  void _refreshStorageValue() {
    if (!_storageMode || _selectedStorage == null) return;
    final quantity = double.tryParse(_quantity.text.trim());
    final value = quantity == null
        ? 0.0
        : _selectedStorage!.estimatedValueFor(quantity);
    final text = wasteNumber(value);
    if (_value.text != text) _value.text = text;
  }

  void _handleStorageFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setEntrySource(WasteEntrySource source) {
    if (_entrySource == source) return;
    setState(() {
      _entrySource = source;
      _selectedStorage = null;
      _storageSearch.clear();
      _name.clear();
      _quantity.clear();
      _value.text = '0';
      _unit = wasteUnits.first;
      _reason = source == WasteEntrySource.storage
          ? 'Spoiled'
          : wasteReasons.first;
    });
    _form.currentState?.reset();
  }

  void _selectStorage(PantryWasteSource source) {
    setState(() {
      _selectedStorage = source;
      _storageSearch.text = source.item.name;
      _name.text = source.item.name;
      _unit = wasteUnitFor(source.item.unit);
      _quantity.clear();
      _value.text = '0';
      if (source.isExpiredAt(ref.read(wasteClockProvider)())) {
        _reason = 'Expired';
      } else if (_reason == 'Expired') {
        _reason = 'Spoiled';
      }
    });
    _form.currentState?.validate();
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

  Widget _sourceSelector() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where is this item from?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('waste-source-storage'),
              selected: _entrySource == WasteEntrySource.storage,
              onSelected: (_) => _setEntrySource(WasteEntrySource.storage),
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('My Storage'),
            ),
            ChoiceChip(
              key: const ValueKey('waste-source-external'),
              selected: _entrySource == WasteEntrySource.external,
              onSelected: (_) => _setEntrySource(WasteEntrySource.external),
              avatar: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Other / External'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 19,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Expired items with saved expiry dates are tracked automatically.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _externalNameField() => RawAutocomplete<String>(
    textEditingController: _name,
    focusNode: _nameFocus,
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      return query.isEmpty
          ? const Iterable<String>.empty()
          : foodItemSuggestions
                .where((name) => name.toLowerCase().startsWith(query))
                .take(8);
    },
    fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
      key: const ValueKey('waste-name'),
      controller: controller,
      focusNode: focus,
      decoration: _fieldDecoration('Item Name', icon: const Icon(Icons.search)),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Enter an item name.' : null,
    ),
    optionsViewBuilder: (context, select, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 72)
              .clamp(0, 528)
              .toDouble(),
          height: 220,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final option in options)
                ListTile(title: Text(option), onTap: () => select(option)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _storageItemField(AsyncValue<List<PantryWasteSource>> storage) {
    if (storage.isLoading) {
      return Semantics(
        label: 'Loading stored items',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 12),
              Flexible(child: Text('Loading stored items...')),
            ],
          ),
        ),
      );
    }
    if (storage.hasError) {
      return const Text(
        'Stored items are unavailable. Try again or use Other / External.',
      );
    }
    final sources = storage.asData?.value ?? const <PantryWasteSource>[];
    if (sources.isEmpty) {
      return const Text(
        'No stored items with remaining quantity are available.',
      );
    }
    final query = _storageSearch.text.trim().toLowerCase();

    final filteredSources = sources
        .where((source) {
          if (query.isEmpty) return true;

          final item = source.item;
          return item.name.toLowerCase().contains(query) ||
              item.category.label.toLowerCase().contains(query) ||
              item.location.label.toLowerCase().contains(query);
        })
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('waste-storage-item'),
          controller: _storageSearch,
          focusNode: _storageFocus,
          onChanged: (value) {
            setState(() {
              final selected = _selectedStorage;
              if (selected != null && value.trim() != selected.item.name) {
                _selectedStorage = null;
                _name.clear();
                _quantity.clear();
                _value.text = '0';
              }
            });
          },
          decoration: _fieldDecoration(
            'Search stored item',
            icon: const Icon(Icons.search),
          ),
          validator: (_) => _selectedStorage == null
              ? 'Select an item from My Storage.'
              : null,
        ),
        if (_storageFocus.hasFocus && filteredSources.isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final source in filteredSources)
                    ListTile(
                      title: Text(source.item.name),
                      subtitle: Text(
                        '${source.item.category.label} • '
                        '${source.item.location.label}\n'
                        '${source.item.quantityLabel} remaining',
                      ),
                      isThreeLine: true,
                      onTap: () {
                        _selectStorage(source);
                        _storageFocus.unfocus();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectedStorageDetails(PantryWasteSource source) {
    final colors = Theme.of(context).colorScheme;
    final expired = source.isExpiredAt(ref.read(wasteClockProvider)());
    return Container(
      key: const ValueKey('waste-storage-details'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.item.name,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${source.item.category.label} • ${source.item.location.label}'),
          Text('Available: ${source.item.quantityLabel}'),
          if (expired) ...[
            const SizedBox(height: 8),
            Text(
              'This expired item is tracked automatically in Waste Tracker.',
              key: const ValueKey('waste-storage-expired'),
              style: TextStyle(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving ||
        _saved ||
        !_sameScope ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      PantryWasteSource? storageSource;
      if (_storageMode) {
        storageSource = _currentStorageSource();
        if (storageSource == null) {
          showWasteMessage(
            context,
            'This stored item is no longer available. Select it again.',
          );
          return;
        }
        final quantity = double.parse(_quantity.text.trim());
        if (quantity > storageSource.item.quantity) {
          showWasteMessage(
            context,
            'Only ${storageSource.item.quantityLabel} is currently available.',
          );
          return;
        }
        if (_isAutomaticExpiry(storageSource)) {
          showWasteMessage(
            context,
            'This expired item is tracked automatically in Waste Tracker.',
          );
          return;
        }
        final confirmed = await _confirmStorageSave(storageSource, quantity);
        if (!mounted || !_sameScope || confirmed != true) return;
        storageSource = _currentStorageSource();
        if (storageSource == null) {
          showWasteMessage(
            context,
            'This stored item is no longer available. Select it again.',
          );
          return;
        }
        if (quantity > storageSource.item.quantity) {
          showWasteMessage(
            context,
            'The available quantity changed. Review the item and try again.',
          );
          return;
        }
        if (_isAutomaticExpiry(storageSource)) {
          showWasteMessage(
            context,
            'This expired item is tracked automatically in Waste Tracker.',
          );
          return;
        }
      }
      final record = FoodWasteRecord(
        id: widget.initialRecord?.id,
        itemName: _name.text.trim(),
        quantity: double.parse(_quantity.text.trim()),
        unit: _unit,
        reason: _reason,
        estimatedValue: storageSource == null
            ? double.parse(_value.text.trim())
            : storageSource.estimatedValueFor(
                double.parse(_quantity.text.trim()),
              ),
        wastedAt: _date,
        source:
            widget.initialRecord?.source ??
            (storageSource == null ? null : manualPantryWasteSource),
        sourcePantryItemId:
            widget.initialRecord?.sourcePantryItemId ??
            storageSource?.item.firestoreId,
      );
      WasteDuplicateWarning? confirmation;
      FoodWasteRecord? saved;
      final capturedScope = _openedScope!;
      while (mounted && _sameScope) {
        try {
          saved = await ref
              .read(foodWasteProvider.notifier)
              .save(
                record,
                confirmedDuplicate: confirmation,
                expectedScope: capturedScope,
              );
          break;
        } on WasteDuplicateWarning catch (warning) {
          if (!mounted || !_sameScope) return;
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
                  storageSource == null
                      ? 'This waste record looks similar to one already saved.'
                      : 'This stored item may already have been recorded as waste.',
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
          if (!mounted || !_sameScope || saveAnyway != true) return;
          setState(() => _choosingDuplicate = false);
          confirmation = warning;
        }
      }
      if (mounted && saved != null) {
        if (storageSource != null) {
          if (!_sameScope || storageSource.scope != capturedScope) {
            var rollbackSucceeded = false;
            try {
              await ref
                  .read(foodWasteProvider.notifier)
                  .rollbackCreated(capturedScope, saved);
              rollbackSucceeded = true;
            } catch (rollbackError) {
              debugPrint('Waste context rollback failed: $rollbackError');
            }
            if (!mounted) return;
            showWasteMessage(
              context,
              rollbackSucceeded
                  ? 'Your pantry context changed. Waste was not recorded. Please try again.'
                  : "We couldn't fully complete this update. Please refresh and check your Waste records and stored quantity.",
            );
            return;
          }
          Object? decrementError;
          try {
            await ref
                .read(pantryWasteActionsProvider)
                .decrementSavedQuantity(storageSource, saved);
          } catch (error) {
            decrementError = error;
            debugPrint('Waste Pantry decrement failed: $error');
          }

          if (decrementError != null) {
            var rollbackSucceeded = false;
            try {
              await ref
                  .read(foodWasteProvider.notifier)
                  .rollbackCreated(capturedScope, saved);
              rollbackSucceeded = true;
            } catch (rollbackError) {
              debugPrint('Waste compensation rollback failed: $rollbackError');
            }
            _refreshStorageAfterFailure(storageSource.scope);
            if (!mounted) return;
            showWasteMessage(
              context,
              rollbackSucceeded
                  ? _storageFailureMessage(decrementError)
                  : "We couldn't fully complete this update. Please refresh and check your Waste records and stored quantity.",
            );
            return;
          }
        }
        _saved = true;
        if (!mounted || !_sameScope) return;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted && _sameScope) showWasteError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _choosingDuplicate = false;
        });
      }
    }
  }

  PantryWasteSource? _currentStorageSource() {
    final selected = _selectedStorage;
    if (selected == null || selected.scope != _openedScope) return null;
    final sources = ref.read(activeWastePantryProvider).asData?.value;
    if (sources == null) return null;
    for (final source in sources) {
      if (source.item.firestoreId == selected.item.firestoreId) {
        return source;
      }
    }
    return null;
  }

  bool _isAutomaticExpiry(PantryWasteSource source) {
    if (source.isExpiredAt(ref.read(wasteClockProvider)())) return true;
    final expiry = source.item.expiryDate;
    if (expiry == null) return false;
    return ref
            .read(foodWasteProvider)
            .asData
            ?.value
            .any(
              (record) =>
                  record.isAutomaticExpiry &&
                  record.sourcePantryItemId == source.item.firestoreId &&
                  record.sourceExpiryDate != null &&
                  wasteExpiryDate(record.sourceExpiryDate!) ==
                      wasteExpiryDate(expiry),
            ) ??
        false;
  }

  void _refreshStorageAfterFailure(WasteScope scope) {
    ref.invalidate(wastePantryItemsProvider(scope));
    if (!mounted) return;
    setState(() {
      _selectedStorage = null;
      _storageSearch.clear();
      _name.clear();
      _quantity.clear();
      _value.text = '0';
    });
  }

  String _storageFailureMessage(Object error) {
    if (error is PantryItemNotFoundException) {
      return 'This stored item is no longer available. Waste was not recorded.';
    }
    if (error is InsufficientPantryQuantityException) {
      return 'The available quantity changed. Waste was not recorded. Select the item again.';
    }
    return 'The stored quantity could not be updated. Waste was not recorded. Please try again.';
  }

  Future<bool?> _confirmStorageSave(PantryWasteSource source, double quantity) {
    final remaining = source.item.quantity - quantity;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.inventory_2_outlined),
        title: const Text('Record stored food as waste?'),
        content: Text(
          'This will record ${wasteNumber(quantity)} ${source.item.unit.displayLabel(quantity)} as waste and reduce the stored quantity from ${wasteNumber(source.item.quantity)} to ${wasteNumber(remaining)}.',
        ),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Record Waste'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = ref.read(wasteClockProvider)().toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(DateTime(1900)) ? _date : DateTime(1900),
      lastDate: _date.isAfter(today) ? _date : today,
    );
    if (mounted && _sameScope && picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wasteScopeProvider, (previous, next) {
      if (next.asData != null &&
          _openedScope != null &&
          next.asData!.value != _openedScope) {
        _expired = true;
      }
    });
    final scope = ref.watch(wasteScopeProvider);
    final records = ref.watch(foodWasteProvider);
    _openedScope ??= scope.asData?.value;
    final storage = _newRecord
        ? ref.watch(activeWastePantryProvider)
        : const AsyncData<List<PantryWasteSource>>([]);
    PantryWasteSource? liveSelection;
    final selectedId = _selectedStorage?.item.firestoreId;
    for (final source in storage.asData?.value ?? const <PantryWasteSource>[]) {
      if (source.scope == _openedScope &&
          source.item.firestoreId == selectedId) {
        liveSelection = source;
      }
    }
    final editing = widget.initialRecord != null;
    return PopScope(
      canPop: !_saving || _expired,
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Edit Waste Record' : 'Record Waste'),
        ),
        body: scope.isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_sameScope
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_scopeChangedMessage),
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
                                if (_newRecord) ...[
                                  const SizedBox(height: 20),
                                  _sourceSelector(),
                                ],
                                const SizedBox(height: 24),
                                if (_storageMode) ...[
                                  _storageItemField(storage),
                                  if (liveSelection != null) ...[
                                    const SizedBox(height: 12),
                                    _selectedStorageDetails(liveSelection),
                                  ],
                                ] else
                                  _externalNameField(),
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const ValueKey('waste-quantity'),
                                  controller: _quantity,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _fieldDecoration(
                                    _storageMode
                                        ? 'Waste Quantity'
                                        : 'Quantity',
                                    prefix: _storageMode ? '$_unit ' : null,
                                  ),
                                  validator: (value) {
                                    final error = _numberError(
                                      value,
                                      positive: true,
                                    );
                                    if (error != null) return error;
                                    final quantity = double.parse(
                                      value!.trim(),
                                    );
                                    if (_storageMode &&
                                        liveSelection != null &&
                                        quantity >
                                            liveSelection.item.quantity) {
                                      return 'Waste quantity cannot exceed ${liveSelection.item.quantityLabel}.';
                                    }
                                    return null;
                                  },
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
                                  onChanged: _storageMode
                                      ? null
                                      : (value) =>
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
                                            onPressed:
                                                _storageMode &&
                                                    liveSelection
                                                            ?.item
                                                            .expiryDate !=
                                                        null &&
                                                    reason == 'Expired'
                                                ? null
                                                : () => setState(
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
                                  readOnly: _storageMode,
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
