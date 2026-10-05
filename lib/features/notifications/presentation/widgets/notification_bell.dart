import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../../expiry/presentation/providers/expiry_notification_settings_provider.dart';
import '../providers/notification_providers.dart';
import 'notification_panel.dart';

/// Starts alert generation from the existing pantry stream.
///
/// Mounted at the app root. It does nothing until a signed-in user is known,
/// so Home tests that never initialize Firebase do not open a pantry listener.
class NotificationSyncHost extends ConsumerStatefulWidget {
  const NotificationSyncHost({super.key});

  @override
  ConsumerState<NotificationSyncHost> createState() =>
      _NotificationSyncHostState();
}

class _NotificationSyncHostState extends ConsumerState<NotificationSyncHost>
    with WidgetsBindingObserver {
  String? _scheduledFor;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refresh(),
    );
  }

  void _refresh() {
    final uid = ref.read(notificationUserIdProvider).asData?.value;
    if (uid == null) return;
    final items = ref.read(pantryItemsProvider).asData?.value;
    if (items != null) _queue(uid, items);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _signature(String uid, List<PantryItem> items) {
    final now = ref.read(notificationClockProvider)();
    final days = ref.read(expiryNotificationSettingsProvider).daysBefore;
    return '${now.year}-${now.month}-${now.day}|$days\n${_pantrySignature(uid, items)}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(notificationUserIdProvider).asData?.value;
    if (uid == null) {
      _scheduledFor = null;
      return const SizedBox.shrink();
    }

    ref.listen(expiryNotificationSettingsProvider, (_, next) => _refresh());

    ref.listen<AsyncValue<List<PantryItem>>>(pantryItemsProvider, (
      previous,
      next,
    ) {
      final items = next.asData?.value;
      if (items == null) return;
      _queue(uid, items);
    });

    final current = ref.watch(pantryItemsProvider).asData?.value;
    if (current != null) {
      final signature = _signature(uid, current);
      if (_scheduledFor != signature) {
        final snapshot = current;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _scheduledFor == signature ||
              ref.read(notificationUserIdProvider).asData?.value != uid) {
            return;
          }
          _scheduledFor = signature;
          unawaited(_synchronize(ref, uid, snapshot));
        });
      }
    }
    return const SizedBox.shrink();
  }

  void _queue(String userId, List<PantryItem> items) {
    final signature = _signature(userId, items);
    if (_scheduledFor == signature) return;
    _scheduledFor = signature;
    Future<void>.microtask(() {
      if (!mounted ||
          ref.read(notificationUserIdProvider).asData?.value != userId) {
        return;
      }
      unawaited(_synchronize(ref, userId, items));
    });
  }
}

String _pantrySignature(String userId, List<PantryItem> items) {
  final parts = [
    for (final item in items)
      '${item.firestoreId ?? item.id}|${item.name}|${item.expiryDate?.millisecondsSinceEpoch ?? ''}|${item.quantity}|${item.unit.name}',
  ]..sort();
  return '$userId\n${parts.join('\n')}';
}

Future<void> _synchronize(
  WidgetRef ref,
  String userId,
  List<PantryItem> items,
) async {
  try {
    await ref
        .read(notificationSyncProvider)
        .synchronize(userId: userId, items: items);
  } catch (error, stack) {
    log(
      'Could not refresh pantry notifications',
      error: error,
      stackTrace: stack,
      name: 'notifications',
    );
  }
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = ref.watch(unreadNotificationCountProvider);
    final label = unread == 0
        ? 'Notifications'
        : 'Notifications, $unread unread';

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: AppStrings.notificationsTooltip,
          child: IconButton(
            onPressed: () => showNotificationPanel(context),
            icon: unread == 0
                ? Icon(
                    Icons.notifications_outlined,
                    color: colorScheme.onSurface,
                  )
                : Badge(
                    key: const ValueKey('notification-unread-badge'),
                    backgroundColor: AppColors.unreadBadge,
                    textColor: Colors.white,
                    label: Text(unread > 9 ? '9+' : '$unread'),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
