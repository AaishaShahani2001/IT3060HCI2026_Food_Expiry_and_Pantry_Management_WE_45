import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_summary.dart';
import '../providers/food_waste_provider.dart';
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

  Future<void> _record([FoodWasteRecord? record]) async {
    if (_busy || _uid == null) return;
    setState(() => _busy = true);
    final session = _session;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => RecordWasteScreen(initialRecord: record),
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
            title: const Text('Delete waste record?'),
            content: const Text('Are you sure you want to delete this record?'),
            actions: [
              TextButton(
                onPressed: () => answer(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
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
    } catch (error) {
      if (mounted && _current(uid, session)) {
        debugPrint('Waste Tracker refresh error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${wasteErrorMessage(error, action: 'refresh')}${hadData ? ' Showing your current waste records.' : ''}',
            ),
          ),
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
        value: wasteNumber(summary.quantity),
        detail: summary.quantityDetail,
        icon: Icons.scale_outlined,
      ),
      WasteSummaryCard(
        title: 'Estimated Value',
        value: wasteMoney(summary.estimatedValue),
        detail: 'Estimated cost of waste',
        icon: Icons.payments_outlined,
      ),
      WasteSummaryCard(
        title: 'Trend vs Previous Period',
        value: trend == null
            ? 'No previous data'
            : '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(0)}%',
        detail: 'Record count vs ${_period.comparisonLabel}. Lower is better.',
        icon: Icons.insights_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final card in cards)
            SizedBox(width: (constraints.maxWidth - 12) / 2, child: card),
        ],
      ),
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
      onRefresh: _refresh,
      child: ListView(
        key: ValueKey(('waste-scroll', uid)),
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!widget.history) ...[
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Small changes\nmake a big difference!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track your food waste and build better habits.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            WastePeriodSelector(
              selected: _period,
              onChanged: (period) => setState(() => _period = period),
            ),
            const SizedBox(height: 16),
            _summaryCards(summary),
            const SizedBox(height: 20),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : () => _record(),
            icon: const Icon(Icons.add),
            label: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Record Waste'),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Text(
                widget.history ? 'All Waste Records' : 'Recent Waste Records',
                style: Theme.of(context).textTheme.titleLarge,
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
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.eco_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    records.isEmpty
                        ? 'No waste recorded yet'
                        : 'No waste recorded in this period',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start tracking food waste to understand your habits.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final record in visible)
            WasteRecordTile(
              key: ValueKey(record.id),
              record: record,
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
