import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_mode_provider.dart';
import '../../../expiry/domain/services/expiry_notification_provider.dart';
import '../../../expiry/presentation/providers/expiry_notification_settings_provider.dart';
import '../../domain/models/app_notification.dart';
import '../providers/notification_providers.dart';

/// Watches alerts across all routes, independently of the notification bell.
class NotificationPopupHost extends ConsumerStatefulWidget {
  const NotificationPopupHost({
    super.key,
    required this.child,
    required this.onView,
  });

  final Widget child;
  final VoidCallback onView;

  @override
  ConsumerState<NotificationPopupHost> createState() =>
      _NotificationPopupHostState();
}

class _NotificationPopupHostState extends ConsumerState<NotificationPopupHost>
    with WidgetsBindingObserver {
  String? _userId;
  Set<String> _seen = {};
  final List<AppNotification> _pending = [];
  final Set<String> _queuedKeys = {};
  List<AppNotification> _visible = [];
  bool _flushScheduled = false;
  Timer? _dismissTimer;
  Timer? _eligibilityTimer;
  int _session = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eligibilityTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refresh(),
    );
  }

  void _refresh() {
    final notifications = ref.read(notificationCenterProvider).asData?.value;
    if (notifications != null) _receive(notifications);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  bool _enabled(AppNotification notification) {
    final settings = ref.read(expiryNotificationSettingsProvider);
    if (!settings.notificationsEnabled) return false;
    final expiry = notification.expiryDate;
    if (expiry != null) {
      final now = ref.read(notificationClockProvider)();
      final days = DateTime(
        expiry.year,
        expiry.month,
        expiry.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (notification.type == AppNotificationType.expiringSoon &&
          (days < 0 || days > settings.daysBefore)) {
        return false;
      }
      if (notification.type == AppNotificationType.expired && days >= 0) {
        return false;
      }
    }
    return switch (notification.type) {
      AppNotificationType.expiringSoon => settings.expiringSoonEnabled,
      AppNotificationType.expired => settings.expiredItemsEnabled,
      AppNotificationType.lowStock => false,
    };
  }

  void _receive(List<AppNotification> notifications) {
    final uid = ref.read(notificationUserIdProvider).asData?.value;
    if (uid == null || uid != _userId) return;
    for (final notification in notifications) {
      if (notification.userId != uid ||
          _seen.contains(notification.alertKey) ||
          _queuedKeys.contains(notification.alertKey)) {
        continue;
      }
      if (notification.isActive &&
          !notification.isRead &&
          _enabled(notification)) {
        _pending.add(notification);
        _queuedKeys.add(notification.alertKey);
      }
    }
    if (_pending.isEmpty || _flushScheduled) return;
    final session = _session;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || session != _session || uid != _userId) return;
      _flushScheduled = false;
      final current = ref.read(notificationCenterProvider).asData?.value ?? [];
      final alerts = current
          .where(
            (notification) =>
                _queuedKeys.contains(notification.alertKey) &&
                notification.userId == uid &&
                notification.isActive &&
                !notification.isRead &&
                _enabled(notification),
          )
          .toList();
      _pending.clear();
      _queuedKeys.clear();
      if (alerts.isEmpty) return;
      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _visible = [..._visible, ...alerts]);
      // Reserve until the next frame, then remember only rendered alerts.
      _queuedKeys.addAll(alerts.map((alert) => alert.alertKey));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || session != _session) return;
        for (final alert in alerts) {
          _queuedKeys.remove(alert.alertKey);
          if (_visible.contains(alert) && _enabled(alert)) {
            _seen.add(alert.alertKey);
          }
        }
        final prefs = ref.read(sharedPreferencesProvider);
        if (prefs != null) {
          unawaited(
            prefs.setStringList('expiry_popup_delivered_$uid', _seen.toList()),
          );
        }
      });
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 8), _dismiss);
      final title = alerts.length == 1
          ? alerts.single.title
          : '${alerts.length} pantry expiry alerts';
      final body = alerts.length == 1
          ? alerts.single.message
          : alerts.map((alert) => alert.title).join('\n');
      unawaited(
        ref
            .read(expiryNotificationServiceProvider)
            .showExpiryNotification(title: title, body: body),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (mounted && _visible.isNotEmpty) setState(() => _visible = []);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eligibilityTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(notificationUserIdProvider).asData?.value;
    if (_userId != uid) {
      _session++;
      _userId = uid;
      _seen =
          ref
              .read(sharedPreferencesProvider)
              ?.getStringList('expiry_popup_delivered_$uid')
              ?.toSet() ??
          {};
      _pending.clear();
      _queuedKeys.clear();
      _flushScheduled = false;
      _visible = [];
      _dismissTimer?.cancel();
    }
    ref.listen(notificationCenterProvider, (_, next) {
      final notifications = next.asData?.value;
      if (notifications != null) _receive(notifications);
    });
    // Also handles an already-loaded provider when this host is remounted.
    final snapshot = ref.watch(notificationCenterProvider).asData?.value;
    if (snapshot != null) _receive(snapshot);
    final settings = ref.watch(expiryNotificationSettingsProvider);
    final visible = _visible.where(_enabled).toList();
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        if (settings.notificationsEnabled && visible.isNotEmpty)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      key: const ValueKey('expiry-notification-popup'),
                      color: colors.surfaceContainerHigh,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notifications_active_outlined,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        visible.length == 1
                                            ? visible.single.title
                                            : '${visible.length} pantry expiry alerts',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        visible.length == 1
                                            ? visible.single.message
                                            : visible
                                                  .map((alert) => alert.title)
                                                  .join('\n'),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Semantics(
                                  label: 'Dismiss expiry alert',
                                  child: IconButton(
                                    key: const ValueKey('dismiss-expiry-alert'),
                                    onPressed: _dismiss,
                                    icon: const Icon(Icons.close, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  _dismiss();
                                  widget.onView();
                                },
                                child: const Text('View expiry items'),
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
      ],
    );
  }
}
