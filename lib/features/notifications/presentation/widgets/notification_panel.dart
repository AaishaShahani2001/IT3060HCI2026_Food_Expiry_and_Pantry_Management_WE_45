import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/notification_planner.dart';
import '../../domain/notification_repository.dart';
import '../../domain/notification_time.dart';
import '../providers/notification_providers.dart';

const double notificationWideLayoutWidth = 700;

Future<void> showNotificationPanel(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  if (size.width < notificationWideLayoutWidth) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        final inset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: SizedBox(
            height: height * 0.72,
            child: const NotificationPanel(),
          ),
        );
      },
    );
  }

  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero)
      : Offset.zero;
  final anchorHeight = box != null && box.hasSize ? box.size.height : 48.0;
  final top = (origin.dy + anchorHeight + 8).clamp(8.0, size.height * 0.2);
  final panelHeight = (size.height - top - 24).clamp(280.0, 560.0);

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Dismiss notifications',
    barrierColor: Colors.black26,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: top,
              right: 16,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                color: Theme.of(dialogContext).colorScheme.surface,
                child: SizedBox(
                  width: 420,
                  height: panelHeight,
                  child: const NotificationPanel(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationCenterProvider);
    final center = ref.read(notificationCenterProvider.notifier);
    final latest = notifications.maybeWhen(
      data: latestActiveNotifications,
      orElse: () => const <AppNotification>[],
    );
    final unread = notifications.maybeWhen(
      data: (items) => items.where((item) => !item.isRead).length,
      orElse: () => 0,
    );
    final hasAny = notifications.maybeWhen(
      data: (items) => items.isNotEmpty,
      orElse: () => false,
    );

    return Material(
      key: const ValueKey('notification-panel'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            unread: unread,
            hasAny: hasAny,
            busy: center.isBulkBusy,
            onMarkAll: () => _markAll(context, ref),
            onDeleteAll: () => _deleteAll(context, ref),
          ),
          const Divider(height: 1),
          Expanded(
            child: notifications.when(
              loading: () => const _PanelLoading(),
              error: (error, stack) => _PanelError(
                onRetry: () =>
                    ref.read(notificationCenterProvider.notifier).retry(),
              ),
              data: (items) {
                if (latest.isEmpty) return const _PanelEmpty();
                return _NotificationList(notifications: latest);
              },
            ),
          ),
          if (latest.isNotEmpty)
            const _SeeAllNotificationsButton(
              key: ValueKey('notification-see-all'),
            ),
        ],
      ),
    );
  }
}

class _SeeAllNotificationsButton extends StatelessWidget {
  const _SeeAllNotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          TextButton(
            onPressed: () => openAllNotifications(context),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('See All'),
                Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Closes the preview, then opens the full notification list.
///
/// The push waits until the next frame. Popping the preview and pushing a
/// route in the same turn rebuilds the navigator while it is still building.
void openAllNotifications(BuildContext context) {
  final router = GoRouter.of(context);
  Navigator.of(context, rootNavigator: true).pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    router.push(AppRoutes.notifications);
  });
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.unread,
    required this.hasAny,
    required this.busy,
    required this.onMarkAll,
    required this.onDeleteAll,
  });

  final int unread;
  final bool hasAny;
  final bool busy;
  final VoidCallback onMarkAll;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Latest updates from your pantry',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: unread == 0 || busy ? null : onMarkAll,
                child: const Text('Mark all as read'),
              ),
              if (hasAny)
                TextButton(
                  onPressed: busy ? null : onDeleteAll,
                  child: const Text('Delete all'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return NotificationTile(notification: notifications[index]);
      },
    );
  }
}

class NotificationTile extends ConsumerWidget {
  const NotificationTile({required this.notification, super.key});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(notificationClockProvider)();
    final age = formatNotificationAge(notification.createdAt, now);
    final style = _styleFor(notification.type);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = ref
        .read(notificationCenterProvider.notifier)
        .busyIds
        .contains(notification.id);
    final background = notification.isRead
        ? Colors.transparent
        : (isDark
              ? FreshPalette.darkAccentSurface
              : FreshPalette.accentSurface);

    return Semantics(
      button: !notification.isRead,
      label:
          '${notification.displayTitle}. ${notification.message}. $age. ${notification.isRead ? 'Read' : 'Unread'}',
      child: Material(
        color: background,
        child: InkWell(
          onTap: notification.isRead || busy
              ? null
              : () => _markRead(context, ref, notification.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.accent.withValues(alpha: isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        age,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    child: Semantics(
                      label: 'Unread',
                      child: Container(
                        key: ValueKey('notification-unread-${notification.id}'),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.unreadBadge,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Notification actions',
                  enabled: !busy,
                  icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
                  onSelected: (value) =>
                      _onAction(context, ref, notification, value),
                  itemBuilder: (context) => [
                    if (!notification.isRead)
                      const PopupMenuItem(
                        value: 'read',
                        child: _MenuLabel(
                          icon: Icons.mark_email_read_outlined,
                          label: 'Mark as read',
                        ),
                      ),
                    if (notification.isRead)
                      const PopupMenuItem(
                        value: 'unread',
                        child: _MenuLabel(
                          icon: Icons.mark_email_unread_outlined,
                          label: 'Mark as unread',
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: _MenuLabel(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'You’re all caught up',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'No new pantry alerts right now.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  const _PanelError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Couldn’t load notifications',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _NotificationStyle {
  const _NotificationStyle({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;
}

_NotificationStyle _styleFor(AppNotificationType type) {
  return switch (type) {
    AppNotificationType.expiringSoon => const _NotificationStyle(
      icon: Icons.schedule_outlined,
      accent: AppColors.statusAmber,
    ),
    AppNotificationType.expired => const _NotificationStyle(
      icon: Icons.event_busy_outlined,
      accent: AppColors.statusRed,
    ),
    AppNotificationType.lowStock => const _NotificationStyle(
      icon: Icons.inventory_2_outlined,
      accent: AppColors.statusFresh,
    ),
  };
}

Future<void> _markRead(BuildContext context, WidgetRef ref, String id) async {
  await _run(
    context,
    () => ref.read(notificationCenterProvider.notifier).markAsRead(id),
    success: 'Notification marked as read',
    announceOnly: true,
  );
}

Future<void> _onAction(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
  String action,
) async {
  final center = ref.read(notificationCenterProvider.notifier);
  switch (action) {
    case 'read':
      await _run(
        context,
        () => center.markAsRead(notification.id),
        success: 'Notification marked as read',
        announceOnly: true,
      );
    case 'unread':
      await _run(
        context,
        () => center.markAsUnread(notification.id),
        success: 'Notification marked as unread',
        announceOnly: true,
      );
    case 'delete':
      await _run(
        context,
        () => center.deleteNotification(notification.id),
        success: 'Notification deleted.',
      );
  }
}

Future<void> _markAll(BuildContext context, WidgetRef ref) {
  return _run(
    context,
    () => ref.read(notificationCenterProvider.notifier).markAllAsRead(),
    success: 'All notifications marked as read.',
  );
}

Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete all notifications?'),
        content: const Text(
          'This will clear all notifications from your notification list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  await _run(
    context,
    () =>
        ref.read(notificationCenterProvider.notifier).deleteAllNotifications(),
    success: 'All notifications deleted.',
  );
}

Future<void> _run(
  BuildContext context,
  Future<bool> Function() action, {
  required String success,
  bool announceOnly = false,
}) async {
  try {
    final changed = await action();
    if (!changed || !context.mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      success,
      Directionality.of(context),
    );
    if (!announceOnly) {
      _showNotice(context, success);
    }
  } on NotificationFailure {
    if (!context.mounted) return;
    _showNotice(
      context,
      'Couldn’t update that notification. Please try again.',
    );
  }
}

void _showNotice(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
