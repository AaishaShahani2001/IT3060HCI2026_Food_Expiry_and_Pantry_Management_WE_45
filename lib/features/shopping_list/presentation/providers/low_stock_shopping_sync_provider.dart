import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';

import 'shopping_list_provider.dart';

class LowStockSyncFeedback {
  const LowStockSyncFeedback(this.uid, this.message);
  final String uid;
  final String message;
}

/// One subscription for the signed-in user, independent of the visible route.
/// A UID-bound service stream avoids pairing cached Pantry UI data with a new
/// account. Pantry's existing service/model own all reads and stock thresholds.
final lowStockShoppingSyncProvider = StreamProvider<LowStockSyncFeedback>((
  ref,
) {
  final uid = ref.watch(shoppingAuthUidProvider).asData?.value;
  if (uid == null) return const Stream.empty();
  final service = ref.watch(pantryFirestoreServiceProvider);
  // Keep the Shopping notifier alive, but never rescan on Shopping changes.
  ref.listen(shoppingListProvider, (_, _) {});
  final sync = _LowStockSync(ref, uid);
  final subscription = service
      .watchPantryItems(userId: uid)
      .listen(
        sync.accept,
        onError: (Object error, StackTrace stack) => sync.readFailed(),
      );
  void stop() {
    sync.stop();
    unawaited(subscription.cancel());
  }

  ref.onDispose(stop);
  return sync.feedback.stream;
});

class _StockJob {
  const _StockJob(this.id, this.episode, this.reactivateBought);
  final String id;
  final int episode;
  final bool reactivateBought;
}

class _LowStockSync {
  _LowStockSync(this.ref, this.uid);
  final Ref ref;
  final String uid;
  final feedback = StreamController<LowStockSyncFeedback>();
  final _queue = <_StockJob>[];
  Map<String, PantryItem> _items = {};
  Map<String, bool> _previous = {};
  final _episodes = <String, int>{};
  int _nextEpisode = 0;
  bool _stopped = false;
  bool _draining = false;
  bool _reportedReadError = false;

  bool get _active =>
      !_stopped &&
      ref.mounted &&
      ref.read(shoppingAuthUidProvider).asData?.value == uid &&
      ref.read(shoppingListRepositoryProvider).isCurrentUser(uid);

  bool _low(PantryItem item) => item.isLowStock || item.isOutOfStock;

  void accept(List<PantryItem> items) {
    if (!_active) return;
    _reportedReadError = false;
    _items = {
      for (final item in items)
        if (item.isConnectedToFirestore &&
            item.quantity.isFinite &&
            item.name.trim().isNotEmpty)
          item.firestoreId!: item,
    };
    _episodes.removeWhere((id, _) => !_items.containsKey(id));
    for (final entry in _items.entries) {
      final low = _low(entry.value);
      if (!low) {
        _episodes.remove(entry.key); // Recovery cancels pending low work too.
      } else if (_previous[entry.key] != true) {
        final episode = ++_nextEpisode;
        _episodes[entry.key] = episode;
        _queue.add(
          _StockJob(entry.key, episode, _previous[entry.key] == false),
        );
      }
    }
    _previous = {for (final e in _items.entries) e.key: _low(e.value)};
    if (!_draining) unawaited(_drain());
  }

  bool _eligible(_StockJob job) =>
      _active &&
      _episodes[job.id] == job.episode &&
      _items[job.id] != null &&
      _low(_items[job.id]!);

  Future<void> _drain() async {
    _draining = true;
    final messages = <String>[];
    var changed = 0;
    var failed = 0;
    try {
      while (_active && _queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        if (!_eligible(job)) continue;
        final item = _items[job.id]!;
        try {
          final result = await ref
              .read(shoppingListProvider.notifier)
              .ensureLowStockItem(
                expectedUid: uid,
                pantryItemId: job.id,
                name: item.name,
                reactivateBought: job.reactivateBought,
                stillEligible: () => _eligible(job),
              );
          if (!_active) break;
          if (result != LowStockShoppingResult.unchanged) {
            changed++;
            final action = result == LowStockShoppingResult.added
                ? 'added to Shopping List'
                : 'moved back to To Buy';
            final reason = item.isOutOfStock ? 'out of stock' : 'stock is low';
            messages.add('${item.name.trim()} $action — $reason.');
          }
        } catch (_) {
          if (!_active) break;
          failed++;
          messages.add("Couldn't add ${item.name.trim()} to Shopping List.");
          // This episode stays consumed; no automatic retry loop.
        }
      }
      if (_active && messages.isNotEmpty) {
        feedback.add(
          LowStockSyncFeedback(
            uid,
            messages.length == 1
                ? messages.single
                : '${changed > 0 ? '$changed low-stock items added or moved to To Buy. ' : ''}'
                          '${failed > 0 ? "Couldn't sync $failed items. Check your Shopping List." : ''}'
                      .trim(),
          ),
        );
      }
    } finally {
      _draining = false;
    }
  }

  void readFailed() {
    if (!_active || _reportedReadError) return;
    _reportedReadError = true;
    feedback.add(
      LowStockSyncFeedback(
        uid,
        "Couldn't check low-stock Pantry items. Please check your Shopping List.",
      ),
    );
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _queue.clear();
    _items.clear();
    _previous.clear();
    _episodes.clear();
    unawaited(feedback.close());
  }
}
