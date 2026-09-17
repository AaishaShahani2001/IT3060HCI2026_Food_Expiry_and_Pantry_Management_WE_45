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

  Future<FoodWasteRecord> save(FoodWasteRecord record) async {
    final uid = _requireUser();
    record.validate();
    if (record.id != null &&
        !state.requireValue.any((r) => r.id == record.id)) {
      throw StateError('The record no longer exists.');
    }
    final generation = _generation;
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
