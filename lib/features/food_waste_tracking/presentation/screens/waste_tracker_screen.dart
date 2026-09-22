import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_summary.dart';
import '../providers/food_waste_provider.dart';
import '../providers/pantry_waste_provider.dart';
import '../widgets/expired_pantry_section.dart';
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
  int _session = 0;
  String? get _uid => ref.read(wasteAuthUidProvider).asData?.value;
  bool _current(String? uid, int session) =>
      mounted &&
      uid != null &&
      _uid == uid &&
      _session == session &&
      ref.read(foodWasteRepositoryProvider).isCurrentUser(uid);

  Future<void> _record([
    FoodWasteRecord? record,
    PantryWasteSource? pantrySource,
  ]) async {
    if (_busy || _uid == null) return;
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
    if (_busy || _uid == null || record.id == null) return;
    final uid = _uid;
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
            content: const Text('Are you sure you want to delete this record?'),
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
      if (confirmed == true && _current(uid, session)) {
        await ref.read(foodWasteProvider.notifier).delete(record.id!);
      }
    } catch (error) {
      if (mounted && _current(uid, session)) {
        showWasteError(context, error, action: 'delete');
      }
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy || _uid == null) return;
    final uid = _uid;
    final session = _session;
    final hadData = ref.read(foodWasteProvider).asData != null;
    setState(() => _busy = true);
    try {
      await ref.read(foodWasteProvider.notifier).reload();
      if (_current(uid, session) && !widget.history) {
        ref.invalidate(wastePantryItemsProvider(uid!));
      }
    } catch (error) {
      if (mounted && _current(uid, session)) {
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
    final uid = _uid;
    final session = _session;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _refresh,
      child: ListView(
        key: ValueKey(('waste-scroll', uid)),
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
          if (!widget.history)
            ExpiredPantrySection(
              onRecord: _busy
                  ? null
                  : (source) {
                      if (_current(source.uid, session)) _record(null, source);
                    },
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
                onEdit: _busy
                    ? null
                    : () {
                        if (_current(uid, session)) _record(record);
                      },
                onDelete: _busy
                    ? null
                    : () {
                        if (_current(uid, session)) _delete(record);
                      },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wasteAuthUidProvider, (previous, next) {
      if (previous?.asData?.value != next.asData?.value) {
        _session++;
        _busy = false;
      }
    });
    final auth = ref.watch(wasteAuthUidProvider);
    final records = ref.watch(foodWasteProvider);
    final Widget body;
    if (auth.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (auth.hasError || auth.asData?.value == null) {
      body = const Center(child: Text('Sign in to view your waste records.'));
    } else {
      body = records.when(
        // A retry should not hide the existing error/retry affordance.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: records.retrying && records.hasError,
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
        title: Text(widget.history ? 'Waste History' : 'Waste Tracker'),
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
