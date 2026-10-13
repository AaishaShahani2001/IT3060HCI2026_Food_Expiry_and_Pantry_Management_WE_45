import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/app_notification.dart';
import '../providers/notification_providers.dart';
import '../widgets/notification_panel.dart';

/// Full notification list for the signed-in user, newest first.
///
/// Uses the same notification center as the preview. The preview still shows
/// only the latest five; this screen does not apply that cap.
class AllNotificationsScreen extends ConsumerWidget {
  const AllNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationCenterProvider);
    final uid = ref.watch(notificationUserIdProvider).asData?.value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: background,
        title: const Text('Notifications'),
      ),
      body: notifications.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        error: (error, stack) => _AllNotificationsMessage(
          icon: Icons.notifications_off_outlined,
          title: 'Couldn’t load notifications',
          message: 'Please try again.',
          action: TextButton(
            onPressed: () =>
                ref.read(notificationCenterProvider.notifier).retry(),
            child: const Text('Retry'),
          ),
        ),
        data: (items) {
          final visible = notificationsForUser(items, uid);
          if (visible.isEmpty) {
            return const _AllNotificationsMessage(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications yet',
              message: 'Pantry alerts will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: visible.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return NotificationTile(notification: visible[index]);
            },
          );
        },
      ),
    );
  }
}

/// Active notifications for [userId], newest first.
///
/// A null or empty [userId] yields nothing, so another account's alerts are
/// not shown while auth is still resolving.
List<AppNotification> notificationsForUser(
  List<AppNotification> notifications,
  String? userId,
) {
  if (userId == null || userId.isEmpty) return const [];
  final visible = [
    for (final notification in notifications)
      if (notification.isActive && notification.userId == userId) notification,
  ];
  visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return List<AppNotification>.unmodifiable(visible);
}

class _AllNotificationsMessage extends StatelessWidget {
  const _AllNotificationsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: isDark
                  ? colorScheme.onSurfaceVariant
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
