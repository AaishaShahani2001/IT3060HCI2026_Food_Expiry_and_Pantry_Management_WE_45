import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../domain/models/shopping_reminder.dart';
import '../../domain/services/shopping_reminder_notification_service.dart';
import 'shopping_list_provider.dart';

String shoppingReminderStorageKey(String uid) => 'shopping_reminder.$uid.group';

final shoppingReminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final shoppingReminderSchedulerProvider = Provider<ShoppingReminderScheduler>(
  (ref) => LocalShoppingReminderScheduler(
    ref.watch(localNotificationsPluginProvider),
  ),
);

typedef ShoppingReminderExpiryTimerFactory =
    Timer Function(Duration duration, void Function() callback);

final shoppingReminderExpiryTimerFactoryProvider =
    Provider<ShoppingReminderExpiryTimerFactory>(
      (ref) =>
          (duration, callback) => Timer(duration, callback),
    );

final shoppingReminderProvider =
    AsyncNotifierProvider<ShoppingReminderNotifier, ShoppingReminder?>(
      ShoppingReminderNotifier.new,
    );

class ShoppingReminderNotifier extends AsyncNotifier<ShoppingReminder?> {
  String? _uid;
  Timer? _expiryTimer;
  var _expiryGeneration = 0;

  @override
  Future<ShoppingReminder?> build() async {
    _cancelExpiryTimer();
    ref.onDispose(_cancelExpiryTimer);
    _uid = await ref.watch(shoppingAuthUidProvider.future);
    final uid = _uid;
    if (uid == null) return null;
    final preferences = ref.watch(sharedPreferencesProvider);
    final raw = preferences?.getString(shoppingReminderStorageKey(uid));
    if (raw == null) return null;

    ShoppingReminder reminder;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid Shopping reminder data.');
      }
      reminder = ShoppingReminder.fromJson(decoded);
    } catch (_) {
      await _removePersistedReminder(uid);
      await ref.read(shoppingReminderSchedulerProvider).cancelAll(uid: uid);
      return null;
    }

    final now = ref.read(shoppingReminderClockProvider)();
    if (!reminder.hasFutureTime(now)) {
      await _removePersistedReminder(uid);
      return null;
    }
    if (reminder.count < 1 ||
        reminder.count > shoppingReminderMaximumCount ||
        reminder.times.toSet().length != reminder.times.length ||
        reminder.times.any(
          (time) => DateTime(time.year, time.month, time.day) != reminder.date,
        )) {
      await ref
          .read(shoppingReminderSchedulerProvider)
          .cancelPending(uid: uid, reminder: reminder, now: now);
      await _removePersistedReminder(uid);
      return null;
    }
    _scheduleExpiryCheck(uid, reminder);
    return reminder;
  }

  void _cancelExpiryTimer() {
    ++_expiryGeneration;
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  void _scheduleExpiryCheck(String uid, ShoppingReminder reminder) {
    _cancelExpiryTimer();
    final generation = _expiryGeneration;
    final now = ref.read(shoppingReminderClockProvider)();
    final delay = reminder.times.last.difference(now);
    if (delay <= Duration.zero) {
      unawaited(_expireIfCompleted(uid, reminder, generation));
      return;
    }
    _expiryTimer = ref.read(shoppingReminderExpiryTimerFactoryProvider)(
      delay,
      () {
        unawaited(_expireIfCompleted(uid, reminder, generation));
      },
    );
  }

  Future<void> _expireIfCompleted(
    String uid,
    ShoppingReminder reminder,
    int generation,
  ) async {
    if (generation != _expiryGeneration || _uid != uid) return;
    if (reminder.hasFutureTime(ref.read(shoppingReminderClockProvider)())) {
      _scheduleExpiryCheck(uid, reminder);
      return;
    }
    await _removePersistedReminder(uid);
    if (generation != _expiryGeneration || _uid != uid) return;
    _cancelExpiryTimer();
    state = const AsyncData(null);
  }

  Future<void> _removePersistedReminder(String uid) async {
    await ref
        .read(sharedPreferencesProvider)
        ?.remove(shoppingReminderStorageKey(uid));
  }

  String _requireUid() {
    final currentUid = ref.read(shoppingAuthUidProvider).asData?.value;
    if (_uid == null || currentUid != _uid) {
      throw StateError('Please sign in again before setting a reminder.');
    }
    return _uid!;
  }

  Future<void> setReminder(ShoppingReminder reminder) async {
    final now = ref.read(shoppingReminderClockProvider)();
    final validation = shoppingReminderValidationMessage(reminder, now);
    if (validation != null) throw ArgumentError(validation);
    final uid = _requireUid();
    final scheduler = ref.read(shoppingReminderSchedulerProvider);
    final previous = state.asData?.value;
    if (previous != null) {
      await scheduler.cancelPending(uid: uid, reminder: previous, now: now);
    }
    await scheduler.schedule(uid: uid, reminder: reminder);
    try {
      final saved =
          await ref
              .read(sharedPreferencesProvider)
              ?.setString(
                shoppingReminderStorageKey(uid),
                jsonEncode(reminder.toJson()),
              ) ??
          true;
      if (!saved) throw StateError('Could not save the Shopping reminder.');
    } catch (_) {
      await scheduler.cancelPending(
        uid: uid,
        reminder: reminder,
        now: ref.read(shoppingReminderClockProvider)(),
      );
      rethrow;
    }
    if (_uid == uid) {
      state = AsyncData(reminder);
      _scheduleExpiryCheck(uid, reminder);
    }
  }

  Future<void> cancelReminder() async {
    final uid = _requireUid();
    final reminder = state.asData?.value;
    if (reminder != null) {
      await ref
          .read(shoppingReminderSchedulerProvider)
          .cancelPending(
            uid: uid,
            reminder: reminder,
            now: ref.read(shoppingReminderClockProvider)(),
          );
    }
    await ref
        .read(sharedPreferencesProvider)
        ?.remove(shoppingReminderStorageKey(uid));
    if (_uid == uid) {
      _cancelExpiryTimer();
      state = const AsyncData(null);
    }
  }
}

String shoppingReminderDateLabel(DateTime date, DateTime now) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final selectedDate = DateTime(local.year, local.month, local.day);
  if (selectedDate == today) return 'Today';
  if (selectedDate == today.add(const Duration(days: 1))) return 'Tomorrow';
  return '${months[local.month - 1]} ${local.day}';
}

String shoppingReminderTimeLabel(DateTime scheduledAt) {
  final local = scheduledAt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String shoppingReminderLabel(ShoppingReminder reminder, DateTime now) {
  final countLabel = reminder.count == 1
      ? '1 reminder'
      : '${reminder.count} reminders';
  return '${shoppingReminderDateLabel(reminder.date, now)} • $countLabel';
}
