import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/food_waste_repository.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_summary.dart';

final foodWasteRepositoryProvider = Provider<FoodWasteRepository>(
  (ref) => FoodWasteRepository(),
);
final wasteAuthUidProvider = StreamProvider<String?>(
  (ref) => FirebaseAuth.instance
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct(),
);
final wasteClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final foodWasteProvider =
    AsyncNotifierProvider<FoodWasteNotifier, List<FoodWasteRecord>>(
      FoodWasteNotifier.new,
    );

/// A local warning, not a database uniqueness constraint. Confirmation belongs
/// to this draft/account/load; refreshed or changed matches require review again.
class WasteDuplicateWarning implements Exception {
  WasteDuplicateWarning._(
    this._uid,
    this._generation,
    this._draft,
    this._matches,
  );
  final String _uid;
  final int _generation;
  final FoodWasteRecord _draft;
  final List<FoodWasteRecord> _matches;
}

bool _similarWaste(FoodWasteRecord a, FoodWasteRecord b) {
  // A linked item may have been logged on an earlier day or at another amount.
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
      // Two kg and two pcs are different quantities, not an accidental duplicate.
      a.unit == b.unit;
}

class FoodWasteNotifier extends AsyncNotifier<List<FoodWasteRecord>> {
  String? _uid;
  int _generation = 0;
  bool _busy = false;
  FoodWasteRepository get _repository => ref.read(foodWasteRepositoryProvider);

  @override
  Future<List<FoodWasteRecord>> build() async {
    final generation = ++_generation;
    _uid = null;
    _busy = false;
    final repository = ref.watch(foodWasteRepositoryProvider);
    final uid = await ref.watch(wasteAuthUidProvider.future);
    if (!ref.mounted || generation != _generation) return [];
    _uid = uid;
    if (uid == null) return [];
    final records = await repository.load(uid);
    return _isCurrent(uid, generation) ? records : [];
  }

  bool _isCurrent(String uid, int generation) =>
      ref.mounted &&
      generation == _generation &&
      _uid == uid &&
      _repository.isCurrentUser(uid);
  String _requireUser() {
    final uid = _uid;
    if (uid == null ||
        !_repository.isCurrentUser(uid) ||
        state.isLoading ||
        state.asData == null ||
        _busy) {
      throw StateError('Account changed or operation pending.');
    }
    return uid;
  }

  Future<void> reload() async {
    if (_busy) return;
    if (state.asData == null) {
      ref.invalidateSelf();
      await future;
      return;
    }
    final uid = _requireUser();
    final generation = _generation;
    _busy = true;
    try {
      final records = await _repository.load(uid);
      if (_isCurrent(uid, generation)) state = AsyncData(records);
    } finally {
      if (ref.mounted && generation == _generation) _busy = false;
    }
  }

  Future<FoodWasteRecord> save(
    FoodWasteRecord record, {
    WasteDuplicateWarning? confirmedDuplicate,
  }) async {
    final uid = _requireUser();
    record.validate();
    if (record.id != null &&
        !state.requireValue.any((r) => r.id == record.id)) {
      throw StateError('The record no longer exists.');
    }
    final generation = _generation;
    final matches = state.requireValue
        .where((r) => r.id != record.id && _similarWaste(r, record))
        .toList();
    final confirmation = confirmedDuplicate;
    final confirmed =
        confirmation != null &&
        confirmation._uid == uid &&
        confirmation._generation == generation &&
        identical(confirmation._draft, record) &&
        confirmation._matches.length == matches.length &&
        matches.every((r) => confirmation._matches.contains(r));
    if (matches.isNotEmpty && !confirmed) {
      throw WasteDuplicateWarning._(uid, generation, record, matches);
    }
    _busy = true;
    try {
      final FoodWasteRecord saved;
      if (record.id == null) {
        saved = await _repository.create(uid, record);
      } else {
        await _repository.update(uid, record);
        saved = record.copyWith(itemName: record.itemName.trim());
      }
      if (_isCurrent(uid, generation)) {
        state = AsyncData(
          newestWasteFirst([
            ...state.requireValue.where((r) => r.id != saved.id),
            saved,
          ]),
        );
      }
      return saved;
    } finally {
      if (ref.mounted && generation == _generation) _busy = false;
    }
  }

  Future<void> delete(String id) async {
    final uid = _requireUser();
    if (!state.requireValue.any((r) => r.id == id)) {
      throw StateError('Record changed.');
    }
    final generation = _generation;
    _busy = true;
    try {
      await _repository.delete(uid, id);
      if (_isCurrent(uid, generation)) {
        state = AsyncData(state.requireValue.where((r) => r.id != id).toList());
      }
    } finally {
      if (ref.mounted && generation == _generation) _busy = false;
    }
  }
}
