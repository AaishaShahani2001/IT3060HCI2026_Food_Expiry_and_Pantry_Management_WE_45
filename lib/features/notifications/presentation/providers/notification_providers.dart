import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../expiry/presentation/providers/expiry_provider.dart';
import '../../../expiry/presentation/providers/expiry_notification_settings_provider.dart';
import '../../data/notification_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/notification_repository.dart';
import '../../domain/notification_sync.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FirestoreNotificationRepository(),
);

/// Signed-in user for the notification center.
///
/// Returns an empty stream value when Firebase is not initialized so Home
/// widget tests can build the bell without a Firebase app.
final notificationUserIdProvider = StreamProvider<String?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return FirebaseAuth.instance
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct();
});

final notificationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final notificationSyncProvider = Provider<NotificationSynchronizer>((ref) {
  return NotificationSynchronizer(
    repository: ref.watch(notificationRepositoryProvider),
    expiryService: ref.watch(expiryServiceProvider),
    clock: ref.watch(notificationClockProvider),
    expiringSoonDays: () =>
        ref.read(expiryNotificationSettingsProvider).daysBefore,
  );
});

final notificationCenterProvider =
    NotifierProvider<NotificationCenter, AsyncValue<List<AppNotification>>>(
      NotificationCenter.new,
    );

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationCenterProvider);
  return notifications.maybeWhen(
    data: (items) =>
        items.where((item) => !item.isRead && item.isActive).length,
    orElse: () => 0,
  );
});

class NotificationCenter extends Notifier<AsyncValue<List<AppNotification>>> {
  StreamSubscription<List<AppNotification>>? _subscription;
  int _ticket = 0;
  String? _listeningTo;
  List<AppNotification> _server = const [];
  AsyncValue<List<AppNotification>> _snapshot = const AsyncLoading();
  final Map<String, AppNotification?> _pending = {};
  final Set<String> _busy = {};
  bool _bulkBusy = false;
  bool _forceAllRead = false;
  bool _forceAllDeleted = false;

  Set<String> get busyIds => Set<String>.unmodifiable(_busy);

  bool get isBulkBusy => _bulkBusy;

  @override
  AsyncValue<List<AppNotification>> build() {
    final uidAsync = ref.watch(notificationUserIdProvider);
    final ticket = ++_ticket;
    _subscription?.cancel();
    _subscription = null;

    ref.onDispose(() {
      _ticket++;
      _subscription?.cancel();
      _subscription = null;
    });

    if (uidAsync.isLoading) {
      return _snapshot.hasValue ? _snapshot : const AsyncLoading();
    }
    if (uidAsync.hasError) {
      _listeningTo = null;
      _snapshot = AsyncError(
        uidAsync.error ?? const NotificationFailure(),
        uidAsync.stackTrace ?? StackTrace.empty,
      );
      return _snapshot;
    }

    final uid = uidAsync.asData?.value;
    if (uid == null || uid.isEmpty) {
      _listeningTo = null;
      _clearTransient();
      _server = const [];
      _snapshot = const AsyncData([]);
      return _snapshot;
    }

    final repository = ref.watch(notificationRepositoryProvider);
    final userChanged = _listeningTo != uid;
    _listeningTo = uid;
    if (userChanged) {
      _clearTransient();
      _server = const [];
      _snapshot = const AsyncLoading();
    }

    var opened = false;
    _subscription = repository
        .watchActive(uid)
        .listen(
          (items) {
            void apply() {
              if (ticket != _ticket || !ref.mounted) return;
              _server = items;
              _reconcile();
            }

            if (!opened) {
              Future<void>.microtask(apply);
            } else {
              apply();
            }
          },
          onError: (Object error, StackTrace stack) {
            void apply() {
              if (ticket != _ticket || !ref.mounted) return;
              _snapshot = AsyncError(error, stack);
              state = _snapshot;
            }

            if (!opened) {
              Future<void>.microtask(apply);
            } else {
              apply();
            }
          },
        );
    opened = true;
    return _snapshot;
  }

  void retry() {
    _listeningTo = null;
    ref.invalidateSelf();
  }

  Future<bool> markAsRead(String id) {
    return _setRead(id, read: true);
  }

  Future<bool> markAsUnread(String id) {
    return _setRead(id, read: false);
  }

  Future<bool> deleteNotification(String id) async {
    if (_busy.contains(id) || _bulkBusy) return false;
    final uid = _listeningTo;
    final existing = _find(id);
    if (uid == null || existing == null) return false;
    _busy.add(id);
    _pending[id] = null;
    _publish();
    try {
      await ref
          .read(notificationRepositoryProvider)
          .deleteNotification(uid, id);
      return true;
    } catch (_) {
      _pending.remove(id);
      _publish();
      throw const NotificationFailure();
    } finally {
      _busy.remove(id);
      _reconcile();
    }
  }

  Future<bool> markAllAsRead() async {
    if (_bulkBusy) return false;
    final uid = _listeningTo;
    if (uid == null) return false;
    final current = _snapshot.asData?.value ?? const <AppNotification>[];
    if (!current.any((item) => !item.isRead && item.isActive)) return false;
    _bulkBusy = true;
    _forceAllRead = true;
    _publish();
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead(uid);
      return true;
    } catch (_) {
      _forceAllRead = false;
      _publish();
      throw const NotificationFailure();
    } finally {
      _bulkBusy = false;
      _reconcile();
    }
  }

  Future<bool> deleteAllNotifications() async {
    if (_bulkBusy) return false;
    final uid = _listeningTo;
    if (uid == null) return false;
    final current = _snapshot.asData?.value ?? const <AppNotification>[];
    if (current.isEmpty) return false;
    _bulkBusy = true;
    _forceAllDeleted = true;
    _publish();
    try {
      await ref
          .read(notificationRepositoryProvider)
          .deleteAllNotifications(uid);
      return true;
    } catch (_) {
      _forceAllDeleted = false;
      _publish();
      throw const NotificationFailure();
    } finally {
      _bulkBusy = false;
      _reconcile();
    }
  }

  Future<bool> _setRead(String id, {required bool read}) async {
    if (_busy.contains(id) || _bulkBusy) return false;
    final uid = _listeningTo;
    final existing = _find(id);
    if (uid == null || existing == null || existing.isRead == read) {
      return false;
    }
    _busy.add(id);
    _pending[id] = read
        ? existing.copyWith(isRead: true, readAt: DateTime.now())
        : existing.copyWith(isRead: false, clearReadAt: true);
    _publish();
    try {
      final repository = ref.read(notificationRepositoryProvider);
      if (read) {
        await repository.markAsRead(uid, id);
      } else {
        await repository.markAsUnread(uid, id);
      }
      return true;
    } catch (_) {
      _pending.remove(id);
      _publish();
      throw const NotificationFailure();
    } finally {
      _busy.remove(id);
      _reconcile();
    }
  }

  AppNotification? _find(String id) {
    for (final item in _compose()) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _reconcile() {
    if (_forceAllDeleted && _server.isEmpty) {
      _forceAllDeleted = false;
    }
    final activeServer = [
      for (final item in _server)
        if (item.deletedAt == null) item,
    ];
    if (_forceAllRead && activeServer.every((item) => item.isRead)) {
      _forceAllRead = false;
    }
    _pending.removeWhere((id, override) {
      AppNotification? match;
      for (final item in _server) {
        if (item.id == id) {
          match = item;
          break;
        }
      }
      if (override == null) return match == null || match.deletedAt != null;
      if (match == null || match.deletedAt != null) return false;
      return match.isRead == override.isRead;
    });
    _publish();
  }

  void _publish() {
    if (!ref.mounted) return;
    _snapshot = AsyncData(_compose());
    state = _snapshot;
  }

  List<AppNotification> _compose() {
    if (_forceAllDeleted) return const [];
    final visible = <AppNotification>[];
    for (final item in _server) {
      if (item.deletedAt != null) continue;
      if (_pending.containsKey(item.id)) {
        final override = _pending[item.id];
        if (override == null) continue;
        visible.add(override);
        continue;
      }
      if (_forceAllRead && !item.isRead) {
        visible.add(
          item.copyWith(isRead: true, readAt: item.readAt ?? DateTime.now()),
        );
      } else {
        visible.add(item);
      }
    }
    return List<AppNotification>.unmodifiable(visible);
  }

  void _clearTransient() {
    _pending.clear();
    _busy.clear();
    _bulkBusy = false;
    _forceAllRead = false;
    _forceAllDeleted = false;
  }
}
