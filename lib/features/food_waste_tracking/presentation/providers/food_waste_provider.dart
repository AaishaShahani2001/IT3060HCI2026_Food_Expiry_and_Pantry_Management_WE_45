import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/features/shared_pantry/data/shared_pantry_service.dart';

import '../../data/food_waste_repository.dart';
import '../../models/automatic_waste_candidate.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_scope.dart';
import '../../models/waste_summary.dart';

final foodWasteRepositoryProvider = Provider<FoodWasteRepository>(
  (ref) => FoodWasteRepository(),
);

typedef WastePantryDisplayNameLoader =
    Future<String?> Function(String pantryId);

/// Reads display-only household metadata from the canonical Pantry document.
/// Personal versus shared scope remains owned by [wasteScopeProvider].
final wastePantryDisplayNameLoaderProvider =
    Provider<WastePantryDisplayNameLoader>((ref) {
      return (pantryId) async {
        final pantry = await SharedPantryService.instance.getPantry(pantryId);
        final name = pantry.data()?['name']?.toString().trim();
        return name == null || name.isEmpty ? null : name;
      };
    });

/// Family-keying prevents a previous household name from being reused while a
/// different Pantry name is loading.
final wastePantryDisplayNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, pantryId) {
      return ref.watch(wastePantryDisplayNameLoaderProvider)(pantryId);
    });

final wasteAuthUidProvider = StreamProvider<String?>(
  (ref) => FirebaseAuth.instance
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct(),
);

final wasteScopeProvider = StreamProvider<WasteScope?>((ref) {
  final repository = ref.watch(foodWasteRepositoryProvider);
  return ref
      .watch(wasteAuthUidProvider)
      .when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        data: (uid) {
          if (uid == null) {
            repository.clearCurrentScope();
            return Stream<WasteScope?>.value(null);
          }
          return repository.watchScope(uid);
        },
        error: (error, stackTrace) =>
            Stream<WasteScope?>.error(error, stackTrace),
        loading: () => const Stream<WasteScope?>.empty(),
      );
});

final wasteClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final foodWasteProvider =
    AsyncNotifierProvider<FoodWasteNotifier, List<FoodWasteRecord>>(
      FoodWasteNotifier.new,
    );

/// A local warning, not a database uniqueness constraint. Confirmation belongs
/// to this draft/scope/load; refreshed or changed matches require review again.
class WasteDuplicateWarning implements Exception {
  WasteDuplicateWarning._(
    this._scope,
    this._generation,
    this._draft,
    this._matches,
  );

  final WasteScope _scope;
  final int _generation;
  final FoodWasteRecord _draft;
  final List<FoodWasteRecord> _matches;
}

bool _similarWaste(FoodWasteRecord a, FoodWasteRecord b) {
  if (a.sourcePantryItemId != null &&
      a.sourcePantryItemId == b.sourcePantryItemId) {
    return true;
  }
  String name(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  final first = a.wastedAt.toLocal();
  final second = b.wastedAt.toLocal();
  return name(a.itemName) == name(b.itemName) &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day &&
      a.reason == b.reason &&
      a.quantity == b.quantity &&
      a.unit == b.unit;
}

class FoodWasteNotifier extends AsyncNotifier<List<FoodWasteRecord>> {
  WasteScope? _scope;
  int _generation = 0;
  bool _busy = false;
  Completer<void>? _idleCompleter;

  FoodWasteRepository get _repository => ref.read(foodWasteRepositoryProvider);

  WasteScope? get currentScope => _scope;

  @override
  Future<List<FoodWasteRecord>> build() async {
    final generation = ++_generation;
    _scope = null;
    _releaseBusyWaiter();
    ref.onDispose(_releaseBusyWaiter);
    final repository = ref.watch(foodWasteRepositoryProvider);
    final scope = await ref.watch(wasteScopeProvider.future);
    if (!ref.mounted || generation != _generation) return [];
    _scope = scope;
    if (scope == null) return [];

    final initial = Completer<List<FoodWasteRecord>>();
    late final StreamSubscription<List<FoodWasteRecord>> subscription;
    subscription = repository
        .watch(scope)
        .listen(
          (records) {
            if (!_isCurrent(scope, generation)) return;
            if (!initial.isCompleted) {
              initial.complete(records);
            } else {
              state = AsyncData(records);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!_isCurrent(scope, generation)) return;
            if (!initial.isCompleted) {
              initial.completeError(error, stackTrace);
            } else {
              state = AsyncError(error, stackTrace);
            }
          },
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return initial.future;
  }

  bool _isCurrent(WasteScope scope, int generation) =>
      ref.mounted &&
      generation == _generation &&
      _scope == scope &&
      _repository.isCurrentScope(scope);

  void _releaseBusyWaiter() {
    _busy = false;
    final completer = _idleCompleter;
    _idleCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _beginOperation() {
    if (_busy) throw StateError('Waste Tracker operation pending.');
    _busy = true;
    _idleCompleter = Completer<void>();
  }

  void _finishOperation(int generation) {
    if (generation != _generation) return;
    _releaseBusyWaiter();
  }

  /// Waits for the current Waste operation without carrying stale work across
  /// an account or Pantry scope change.
  Future<void> waitUntilIdleFor(WasteScope expectedScope) async {
    final generation = _generation;
    while (true) {
      if (!_isCurrent(expectedScope, generation)) {
        throw const WasteScopeChangedException();
      }
      if (!_busy) return;
      final idle = _idleCompleter;
      if (idle == null) {
        throw StateError('Waste Tracker operation pending.');
      }
      await idle.future;
    }
  }

  WasteScope _requireScope([WasteScope? expectedScope]) {
    final scope = _scope;
    if (scope == null ||
        !_repository.isCurrentScope(scope) ||
        (expectedScope != null && expectedScope != scope)) {
      throw const WasteScopeChangedException();
    }
    if (state.isLoading || state.asData == null || _busy) {
      throw StateError('Waste Tracker operation pending.');
    }
    return scope;
  }

  List<FoodWasteRecord> _upsert(
    Iterable<FoodWasteRecord> records,
    FoodWasteRecord replacement,
  ) => newestWasteFirst([
    ...records.where((record) => record.id != replacement.id),
    replacement,
  ]);

  Future<void> reload() async {
    if (_busy) return;
    if (state.asData == null) {
      ref.invalidateSelf();
      await future;
      return;
    }
    final scope = _requireScope();
    final generation = _generation;
    _beginOperation();
    try {
      final records = await _repository.load(scope);
      if (_isCurrent(scope, generation)) state = AsyncData(records);
    } finally {
      _finishOperation(generation);
    }
  }

  Future<FoodWasteRecord> save(
    FoodWasteRecord record, {
    WasteDuplicateWarning? confirmedDuplicate,
    WasteScope? expectedScope,
  }) async {
    final scope = _requireScope(expectedScope);
    record.validate();
    if (record.id != null &&
        !state.requireValue.any((existing) => existing.id == record.id)) {
      throw StateError('The record no longer exists.');
    }
    final generation = _generation;
    final matches = state.requireValue
        .where(
          (existing) =>
              existing.id != record.id && _similarWaste(existing, record),
        )
        .toList();
    final confirmation = confirmedDuplicate;
    final confirmed =
        confirmation != null &&
        confirmation._scope == scope &&
        confirmation._generation == generation &&
        identical(confirmation._draft, record) &&
        confirmation._matches.length == matches.length &&
        matches.every(confirmation._matches.contains);
    if (matches.isNotEmpty && !confirmed) {
      throw WasteDuplicateWarning._(scope, generation, record, matches);
    }

    _beginOperation();
    try {
      final saved = record.id == null
          ? await _repository.create(scope, record)
          : await _repository.update(scope, record);
      if (_isCurrent(scope, generation)) {
        state = AsyncData(_upsert(state.requireValue, saved));
      }
      return saved;
    } finally {
      _finishOperation(generation);
    }
  }

  Future<void> delete(String id, {WasteScope? expectedScope}) async {
    final scope = _requireScope(expectedScope);
    if (!state.requireValue.any((record) => record.id == id)) {
      throw StateError('Record changed.');
    }
    final generation = _generation;
    _beginOperation();
    try {
      await _repository.delete(scope, id);
      if (_isCurrent(scope, generation)) {
        state = AsyncData(
          state.requireValue.where((record) => record.id != id).toList(),
        );
      }
    } finally {
      _finishOperation(generation);
    }
  }

  Future<void> deleteMany(
    Set<String> ids, {
    required WasteScope expectedScope,
  }) async {
    final scope = _requireScope(expectedScope);
    if (ids.isEmpty) throw ArgumentError('Expected Waste record IDs.');
    final selected = state.requireValue
        .where((record) => record.id != null && ids.contains(record.id))
        .toList();
    if (selected.length != ids.length ||
        selected.any((record) => record.isAutomaticExpiry)) {
      throw StateError('Selected Waste records changed.');
    }
    final generation = _generation;
    _beginOperation();
    try {
      await _repository.deleteMany(scope, ids);
      if (_isCurrent(scope, generation)) {
        state = AsyncData(
          state.requireValue
              .where((record) => !ids.contains(record.id))
              .toList(),
        );
      }
    } finally {
      _finishOperation(generation);
    }
  }

  Future<void> rollbackCreated(
    WasteScope capturedScope,
    FoodWasteRecord record,
  ) async {
    await _repository.rollbackCreated(capturedScope, record);
    if (_scope == capturedScope && state.asData != null) {
      state = AsyncData(
        state.requireValue.where((entry) => entry.id != record.id).toList(),
      );
    }
  }

  Future<bool> reconcileAutomatic(
    List<AutomaticWasteCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return false;
    final scope = _requireScope(candidates.first.scope);
    if (candidates.any((candidate) => candidate.scope != scope)) {
      throw const WasteScopeChangedException();
    }
    final generation = _generation;
    _beginOperation();
    try {
      final changed = await _repository.reconcileAutomatic(scope, candidates);
      if (!_isCurrent(scope, generation)) {
        throw const WasteScopeChangedException();
      }
      return changed;
    } finally {
      _finishOperation(generation);
    }
  }

  Future<void> markNotWasted(
    FoodWasteRecord record, {
    WasteScope? expectedScope,
  }) async {
    final scope = _requireScope(expectedScope);
    if (record.id == null ||
        !record.isAutomaticExpiry ||
        !state.requireValue.any((existing) => identical(existing, record))) {
      throw StateError('Automatic waste record changed.');
    }
    final generation = _generation;
    _beginOperation();
    try {
      await _repository.markNotWasted(scope, record);
      if (_isCurrent(scope, generation)) {
        state = AsyncData(
          state.requireValue.where((entry) => entry.id != record.id).toList(),
        );
      }
    } finally {
      _finishOperation(generation);
    }
  }
}
