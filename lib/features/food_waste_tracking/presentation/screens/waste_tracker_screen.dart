import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_scope.dart';
import '../../models/waste_summary.dart';
import '../providers/food_waste_provider.dart';
import '../providers/pantry_waste_provider.dart';
import '../widgets/waste_motion.dart';
import '../waste_feedback.dart';
import '../widgets/waste_period_selector.dart';
import '../widgets/waste_record_tile.dart';
import '../widgets/waste_summary_card.dart';
import 'record_waste_screen.dart';
import 'waste_history_screen.dart';

class WasteTrackerScreen extends ConsumerStatefulWidget {
  const WasteTrackerScreen({super.key, this.history = false});
  final bool history;
  @override
  ConsumerState<WasteTrackerScreen> createState() => _WasteTrackerScreenState();
}

class _WasteTrackerScreenState extends ConsumerState<WasteTrackerScreen> {
  WastePeriod _period = WastePeriod.today;
  bool _busy = false;
  bool _reconciling = false;
  bool _reconcileScheduled = false;
  bool _reconcileAgain = false;
  int _session = 0;
  final Set<String> _selectedRecordIds = {};
  WasteScope? _selectionScope;
  bool get _selecting =>
      _selectionScope != null && _selectedRecordIds.isNotEmpty;
  WasteScope? get _scope => ref.read(wasteScopeProvider).asData?.value;

  String? _pantryDisplayName(WasteScope scope) {
    final pantryId = scope.pantryId;
    if (!scope.isShared || pantryId == null) return null;
    return ref.read(wastePantryDisplayNameProvider(pantryId)).asData?.value;
  }

  Widget _scopeTitle(
    BuildContext context,
    WasteScope? scope,
    String? pantryName,
  ) {
    final shared = scope?.isShared == true;
    final title = scope == null
        ? (widget.history ? 'Waste History' : 'Waste Tracker')
        : shared
        ? pantryName == null
              ? (widget.history
                    ? 'Shared Waste History'
                    : 'Shared Waste Tracker')
              : widget.history
              ? '$pantryName Waste History'
              : '$pantryName Waste Tracker'
        : widget.history
        ? 'My Waste History'
        : 'My Waste Tracker';
    final subtitle = scope == null
        ? null
        : shared
        ? 'Shared household waste'
        : 'Only visible to you';
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (subtitle == null) return titleWidget;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleWidget,
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  bool _current(WasteScope? scope, int session) =>
      mounted &&
      scope != null &&
      _scope == scope &&
      _session == session &&
      ref.read(foodWasteRepositoryProvider).isCurrentScope(scope);

  void _toggleSelection(FoodWasteRecord record) {
    final id = record.id;
    final scope = _scope;
    if (_busy || record.isAutomaticExpiry || id == null || scope == null) {
      return;
    }
    if (_selectionScope != null && _selectionScope != scope) return;
    setState(() {
      _selectionScope ??= scope;
      if (!_selectedRecordIds.add(id)) _selectedRecordIds.remove(id);
      if (_selectedRecordIds.isEmpty) _selectionScope = null;
    });
  }

  void _cancelSelection() {
    if (!_selecting) return;
    setState(() {
      _selectedRecordIds.clear();
      _selectionScope = null;
    });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      foodWasteProvider,
      (_, _) => _scheduleAutomaticReconciliation(),
      fireImmediately: true,
    );
    ref.listenManual(
      expiredWastePantryProvider,
      (_, _) => _scheduleAutomaticReconciliation(),
      fireImmediately: true,
    );
  }

  void _scheduleAutomaticReconciliation() {
    if (_reconciling) {
      _reconcileAgain = true;
      return;
    }
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    Future<void>.microtask(() async {
      _reconcileScheduled = false;
      if (!mounted || _reconciling) return;
      final scope = _scope;
      if (scope == null) return;
      final session = _session;
      _reconciling = true;
      try {
        final notifier = ref.read(foodWasteProvider.notifier);
        await notifier.waitUntilIdleFor(scope);
        if (!_current(scope, session)) return;
        final records = ref.read(foodWasteProvider).asData?.value;
        final sources = ref.read(expiredWastePantryProvider).asData?.value;
        if (records == null || sources == null) return;
        final existingIds = {for (final record in records) record.id};
        final candidates = sources
            .where((source) => source.scope == scope)
            .map((source) => source.automaticCandidate())
            .where((candidate) => !existingIds.contains(candidate.eventId))
            .toList();
        if (candidates.isEmpty || !_current(scope, session)) return;
        await ref
            .read(foodWasteProvider.notifier)
            .reconcileAutomatic(candidates);
      } on WasteScopeChangedException {
        // Account and Pantry scope changes deliberately discard deferred work.
      } catch (error) {
        // The Pantry stream or a later refresh will retry. Existing Waste data
        // remains usable while the transient reconciliation failure is logged.
        debugPrint('Automatic waste reconciliation error: $error');
      } finally {
        _reconciling = false;
        if (_reconcileAgain) {
          _reconcileAgain = false;
          _scheduleAutomaticReconciliation();
        }
      }
    });
  }

  Future<void> _record([
    FoodWasteRecord? record,
    PantryWasteSource? pantrySource,
  ]) async {
    if (_busy || _scope == null) return;
    setState(() => _busy = true);
    final session = _session;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => RecordWasteScreen(
            initialRecord: record,
            pantrySource: pantrySource,
          ),
        ),
      );
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _delete(FoodWasteRecord record) async {
    if (_busy || _scope == null || record.id == null) return;
    final scope = _scope;
    final pantryName = _pantryDisplayName(scope!);
    final session = _session;
    setState(() => _busy = true);
    try {
      bool answered = false;
      final confirmed = await showDialog<bool>(
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
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Delete waste record?'),
            content: Text(
              scope.isShared
                  ? pantryName == null
                        ? 'This will remove this record from the shared Waste Tracker for all household members.'
                        : 'This will remove this record from the $pantryName Waste Tracker for all household members.'
                  : 'Are you sure you want to delete this record?',
            ),
            actions: [
              TextButton(
                onPressed: () => answer(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                ),
                onPressed: () => answer(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
      if (confirmed == true && _current(scope, session)) {
        await ref
            .read(foodWasteProvider.notifier)
            .delete(record.id!, expectedScope: scope);
      }
    } catch (error) {
      if (mounted && _current(scope, session)) {
        showWasteError(context, error, action: 'delete');
      }
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    final scope = _selectionScope;
    final ids = Set<String>.of(_selectedRecordIds);
    if (_busy || scope == null || ids.isEmpty) return;
    final records = ref.read(foodWasteProvider).asData?.value;
    if (!_current(scope, _session) ||
        records == null ||
        ids.any(
          (id) => !records.any(
            (record) => record.id == id && !record.isAutomaticExpiry,
          ),
        )) {
      _cancelSelection();
      return;
    }
    final session = _session;
    final pantryName = _pantryDisplayName(scope);
    setState(() => _busy = true);
    try {
      final count = ids.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            count == 1
                ? 'Delete 1 waste record?'
                : 'Delete $count waste records?',
          ),
          content: Text(
            'Deleting ${count == 1 ? 'this record' : 'these records'} will not '
            'restore Pantry quantities.'
            '${scope.isShared
                ? pantryName == null
                      ? ' Shared household records will be removed for all members.'
                      : ' These records will be removed from the $pantryName Waste Tracker for all household members.'
                : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true &&
          _current(scope, session) &&
          _selectionScope == scope &&
          _selectedRecordIds.length == ids.length &&
          _selectedRecordIds.containsAll(ids)) {
        await ref
            .read(foodWasteProvider.notifier)
            .deleteMany(ids, expectedScope: scope);
        if (mounted && _current(scope, session)) {
          setState(() {
            _selectedRecordIds.clear();
            _selectionScope = null;
          });
        }
      }
    } catch (error) {
      if (mounted && _current(scope, session)) {
        showWasteError(context, error, action: 'delete');
      }
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _markNotWasted(FoodWasteRecord record) async {
    if (_busy || _scope == null || record.id == null) return;
    final scope = _scope;
    final session = _session;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: const Icon(Icons.undo_outlined),
          title: const Text('Mark as not wasted?'),
          content: Text(
            '${record.itemName} will be removed from Waste totals. '
            'Its Pantry item will not be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Not Wasted'),
            ),
          ],
        ),
      );
      if (confirmed == true && _current(scope, session)) {
        await ref
            .read(foodWasteProvider.notifier)
            .markNotWasted(record, expectedScope: scope);
        if (mounted && _current(scope, session)) {
          showWasteMessage(context, '${record.itemName} marked as not wasted.');
        }
      }
    } catch (error) {
      if (mounted && _current(scope, session)) {
        showWasteError(context, error, action: 'update');
      }
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy || _scope == null) return;
    final scope = _scope;
    final session = _session;
    final hadData = ref.read(foodWasteProvider).asData != null;
    setState(() => _busy = true);
    try {
      await ref.read(foodWasteProvider.notifier).reload();
      if (_current(scope, session)) {
        ref.invalidate(wastePantryItemsProvider(scope!));
      }
    } catch (error) {
      if (mounted && _current(scope, session)) {
        debugPrint('Waste Tracker refresh error: $error');
        showWasteMessage(
          context,
          hadData
              ? "Couldn't refresh. Showing current data."
              : wasteErrorMessage(error, action: 'refresh'),
        );
      }
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Widget _summaryCards(WasteSummary summary) {
    final trend = summary.trendPercent;
    final cards = [
      WasteSummaryCard(
        title: 'Items Wasted',
        value: '${summary.count}',
        detail: 'Waste records',
        icon: Icons.delete_outline,
      ),
      WasteSummaryCard(
        title: 'Quantity Logged',
        value: summary.quantityValue,
        detail: summary.quantityDetail,
        icon: Icons.scale_outlined,
      ),
      WasteSummaryCard(
        title: 'Estimated Value',
        value: wasteMoney(summary.estimatedValue),
        detail: 'Cost of logged waste',
        icon: Icons.payments_outlined,
      ),
      WasteSummaryCard(
        title: 'Trend vs Previous Period',
        value: summary.trendValue,
        detail: summary.trendDetail,
        compactValue: trend == null || trend == 0,
        valueColor: trend == null || trend == 0
            ? null
            : trend < 0
            ? Theme.of(context).colorScheme.primary
            : Colors.brown.shade700,
        icon: Icons.insights_outlined,
      ),
    ];
    // Natural row heights keep the 2x2 grid balanced without clipping large text.
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[row * 2]),
                const SizedBox(width: 10),
                Expanded(child: cards[row * 2 + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _list(List<FoodWasteRecord> records) {
    final summary = WasteSummary(
      records,
      _period,
      ref.read(wasteClockProvider)(),
    );
    final visible = widget.history ? newestWasteFirst(records) : summary.recent;
    final scope = _scope;
    final session = _session;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _refresh,
      child: ListView(
        key: ValueKey(('waste-scroll', scope?.identity)),
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!widget.history) ...[
            WasteEntrance(
              child: WasteSurface(
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.eco_outlined,
                          size: 22,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Track waste. Build better habits.',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            WastePeriodSelector(
              selected: _period,
              onChanged: (period) => setState(() => _period = period),
            ),
            const SizedBox(height: 12),
            WasteEntrance(
              key: ValueKey(('summary', _period)),
              child: _summaryCards(summary),
            ),
            if (summary.reasonInsight != null) ...[
              const SizedBox(height: 10),
              Semantics(
                label: 'Insight',
                child: Text(
                  summary.reasonInsight!,
                  key: const ValueKey('waste-insight'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          WastePress(
            enabled: !_busy,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                elevation: 2,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _busy ? null : () => _record(),
              icon: const Icon(Icons.add),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Record Waste'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Text(
                widget.history ? 'All Waste Records' : 'Recent Waste Records',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!widget.history)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WasteHistoryScreen(),
                          ),
                        ),
                  child: const Text('See all >'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: wasteMotionDuration(context),
            child: visible.isEmpty
                ? Padding(
                    key: const ValueKey('waste-empty'),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.eco_outlined, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          widget.history
                              ? 'No waste recorded yet'
                              : switch (_period) {
                                  WastePeriod.today =>
                                    'No waste recorded today',
                                  WastePeriod.week =>
                                    'No waste recorded this week',
                                  WastePeriod.month =>
                                    'No waste recorded this month',
                                },
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Keep tracking to understand your habits. Every record helps.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('waste-has-records')),
          ),
          for (final record in visible)
            WasteEntrance(
              key: ValueKey(record.id),
              child: WasteRecordTile(
                key: ValueKey(record.id),
                record: record,
                now: ref.read(wasteClockProvider)(),
                selected:
                    !record.isAutomaticExpiry &&
                    record.id != null &&
                    _selectedRecordIds.contains(record.id),
                onTap: _selecting && !record.isAutomaticExpiry
                    ? () {
                        if (_current(scope, session)) _toggleSelection(record);
                      }
                    : null,
                onLongPress: _busy || record.isAutomaticExpiry
                    ? null
                    : () {
                        if (_current(scope, session)) _toggleSelection(record);
                      },
                onEdit: _busy || record.isAutomaticExpiry
                    ? null
                    : () {
                        if (_current(scope, session)) _record(record);
                      },
                onDelete: _busy || record.isAutomaticExpiry
                    ? null
                    : () {
                        if (_current(scope, session)) _delete(record);
                      },
                onNotWasted: _busy || !record.isAutomaticExpiry
                    ? null
                    : () {
                        if (_current(scope, session)) _markNotWasted(record);
                      },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wasteScopeProvider, (previous, next) {
      if (previous?.asData?.value != next.asData?.value) {
        _session++;
        _busy = false;
        _selectedRecordIds.clear();
        _selectionScope = null;
      }
    });
    final auth = ref.watch(wasteAuthUidProvider);
    final scope = ref.watch(wasteScopeProvider);
    final activeScope = scope.asData?.value;
    final pantryId = activeScope?.isShared == true
        ? activeScope?.pantryId
        : null;
    final pantryName = pantryId == null
        ? null
        : ref.watch(wastePantryDisplayNameProvider(pantryId)).asData?.value;
    final records = ref.watch(foodWasteProvider);
    final Widget body;
    if (auth.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (auth.hasError || auth.asData?.value == null) {
      body = const Center(child: Text('Sign in to view your waste records.'));
    } else if (scope.isLoading ||
        (!scope.hasError && scope.asData?.value == null)) {
      body = const Center(child: CircularProgressIndicator());
    } else if (scope.hasError || scope.asData?.value == null) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Waste Tracker could not verify the active pantry. Please try again.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = records.when(
        // Scope transitions must not render records from the previous scope.
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: _list,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  wasteErrorMessage(error, action: 'load'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _selecting ? kToolbarHeight : 72,
        leading: _selecting
            ? IconButton(
                tooltip: 'Cancel selection',
                onPressed: _busy ? null : _cancelSelection,
                icon: const Icon(Icons.close),
              )
            : null,
        title: _selecting
            ? Text('${_selectedRecordIds.length} selected')
            : _scopeTitle(context, activeScope, pantryName),
        actions: [
          if (_selecting)
            IconButton(
              tooltip: 'Delete selected waste records',
              onPressed: _busy ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: body,
        ),
      ),
    );
  }
}
