import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../domain/repositories/expiry_repository.dart';
import '../../domain/services/expiry_service.dart';
import '../providers/expiry_provider.dart';
import '../widgets/empty_expiry_state.dart';
import '../widgets/expiry_alert_card.dart';
import '../widgets/expiry_status_filter_bar.dart';
import '../widgets/stop_tracking_dialog.dart';
import '../widgets/empty_expiry_state.dart';

class ExpiryTrackingActions extends StatelessWidget {
  const ExpiryTrackingActions({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width - 32,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: OutlinedButton(
              key: const ValueKey('track-waste-button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                context.push(AppRoutes.wasteTracker);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Track Waste'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: FilledButton(
              key: const ValueKey('track-item-expiry-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                context.push(AppRoutes.addExpiryTracking);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Track Item Expiry'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = featurePageBackground(context);
    final itemsAsync = ref.watch(pantryItemsProvider);
    final headingColor = isDark ? colorScheme.onSurface : FreshPalette.heading;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: headingColor,
        elevation: 0,
        title: Text(
          'Expiry Monitoring',
          style: TextStyle(color: headingColor, fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            tooltip: 'Expiry Notifications',
            icon: Icon(
              Icons.notifications_active_outlined,
              color: headingColor,
            ),

            onPressed: () {
              context.push(
                AppRoutes.expiryNotifications,
              );
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ExpiryLoadError(
          onRetry: () {
            ref.read(pantryItemsProvider.notifier).refreshItems();
          },
        ),
        data: (_) => const _ExpiryDashboard(),
      ),
    );
  }
}

class _ExpiryDashboard extends ConsumerWidget {
  const _ExpiryDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Derive status counts from the full expiry list so filtering does
    // not change the numbers shown in the summary labels.
    final summary = ref.watch(expirySummaryProvider);
    final selectedFilter = ref.watch(expiryStatusFilterProvider);
    final items = ref.watch(filteredExpiryItemsProvider);
    final groups = ref.watch(groupedExpiryItemsProvider);
    final expiryService = ref.read(expiryServiceProvider);
    final secondaryColor = isDark
        ? colorScheme.onSurfaceVariant
        : FreshPalette.secondaryText;
    final trackedCount = expiryStatusFilterCount(
      summary,
      ExpiryStatusFilter.all,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Monitor your products and take action before food expires.',
          style: theme.textTheme.bodyMedium?.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 16),
        ExpiryStatusFilterBar(
          selected: selectedFilter,
          counts: summary,
          onSelected: (filter) {
            ref.read(expiryStatusFilterProvider.notifier).select(filter);
          },
        ),
        const SizedBox(height: 16),
        const ExpiryTrackingActions(),
        const SizedBox(height: 16),
        if (items.isEmpty)
          EmptyExpiryState(
            message: _emptyMessage(selectedFilter, trackedCount),
            detail:
                selectedFilter == ExpiryStatusFilter.all || trackedCount == 0
                ? 'Track a pantry item to monitor its expiry date.'
                : null,
            actionLabel:
                selectedFilter == ExpiryStatusFilter.all || trackedCount == 0
                ? null
                : 'Show All',
            onAction:
                selectedFilter == ExpiryStatusFilter.all || trackedCount == 0
                ? null
                : () {
                    ref
                        .read(expiryStatusFilterProvider.notifier)
                        .select(ExpiryStatusFilter.all);
                  },
          )
        else ...[
          ..._prioritySection(
            context,
            ref,
            expiryService,
            title: 'USE FIRST',
            badge: 'HIGH PRIORITY',
            accent: AppColors.statusOrange,
            badgeBackground: AppColors.statusOrangeBg,
            items: groups.useFirst,
            itemBadge: 'USE FIRST',
          ),
          ..._prioritySection(
            context,
            ref,
            expiryService,
            title: 'EXPIRING SOON',
            accent: AppColors.statusAmber,
            items: groups.expiringSoon,
          ),
          ..._prioritySection(
            context,
            ref,
            expiryService,
            title: 'EXPIRED ITEMS',
            badge: 'Action Needed',
            accent: AppColors.statusRed,
            badgeBackground: AppColors.statusRedBg,
            items: groups.expired,
          ),
          for (final item in groups.outsidePriority)
            _expiryItemCard(context, ref, expiryService, item),
        ],
      ],
    );
  }
}

List<Widget> _prioritySection(
  BuildContext context,
  WidgetRef ref,
  ExpiryService expiryService, {
  required String title,
  required Color accent,
  required List<PantryItem> items,
  String? badge,
  Color? badgeBackground,
  String? itemBadge,
}) {
  if (items.isEmpty) return const [];

  final countLabel = items.length == 1 ? '1 item' : '${items.length} items';

  return [
    _ExpirySectionHeader(
      title: title,
      badge: badge,
      accent: accent,
      badgeBackground: badgeBackground,
      countLabel: countLabel,
    ),
    for (final item in items)
      _expiryItemCard(context, ref, expiryService, item, badgeText: itemBadge),
  ];
}

Widget _expiryItemCard(
  BuildContext context,
  WidgetRef ref,
  ExpiryService expiryService,
  PantryItem item, {
  String? badgeText,
}) {
  final alert = _alertFor(item, expiryService);

  return ExpiryAlertCard(
    key: ValueKey(item.id),
    name: item.name,
    quantity: item.quantityLabel,
    message: expiryService.expiryMessage(item),
    status: item.expiryStatus,
    badgeText: badgeText,
    onUpdate: () {
      context.push(AppRoutes.editExpiryTracking, extra: alert);
    },
    onStopTracking: () async {
      final confirm = await showStopTrackingDialog(context);
      if (confirm != true || !context.mounted) return;
      await ref.read(stopTrackingProvider)(alert.id);
    },
  );
}

String _emptyMessage(ExpiryStatusFilter filter, int trackedCount) {
  return switch (filter) {
    ExpiryStatusFilter.all => 'No expiry items',
    ExpiryStatusFilter.fresh =>
      trackedCount == 0 ? 'No expiry items' : 'No fresh items found',
    ExpiryStatusFilter.expiringSoon =>
      trackedCount == 0 ? 'No expiry items' : 'No items expiring soon',
    ExpiryStatusFilter.expired =>
      trackedCount == 0 ? 'No expiry items' : 'No expired items',
  };
}

ExpiryAlert _alertFor(PantryItem item, ExpiryService service) {
  final expiryDate = item.expiryDate ?? DateTime.now();
  return ExpiryAlert(
    id: item.id,
    userId: '',
    itemId: item.id,
    itemName: item.name,
    expiryDate: expiryDate,
    daysUntilExpiry: service.daysUntilExpiry(item) ?? 0,
    status: 'active',
    priority: service.alertPriority(item),
    message: service.expiryMessage(item),
    isRead: false,
    createdAt: DateTime.now(),
  );
}

class _ExpirySectionHeader extends StatelessWidget {
  const _ExpirySectionHeader({
    required this.title,
    required this.accent,
    required this.countLabel,
    this.badge,
    this.badgeBackground,
  });

  final String title;
  final String? badge;
  final Color accent;
  final Color? badgeBackground;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor = isDark
        ? theme.colorScheme.onSurface
        : FreshPalette.heading;
    final countColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : FreshPalette.secondaryText;
    final badgeFill = isDark
        ? accent.withValues(alpha: 0.2)
        : (badgeBackground ?? accent.withValues(alpha: 0.12));

    return Semantics(
      header: true,
      label: badge == null
          ? '$title, $countLabel'
          : '$title, $badge, $countLabel',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(Icons.circle, size: 8, color: accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: headingColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              countLabel,
              style: theme.textTheme.bodyMedium?.copyWith(color: countColor),
            ),
          ],
        ),
      ),
    );
  }


  // ==========================================================
  // TRACKED EXPIRY CARD
  // ==========================================================

  static Widget _buildTrackedCard({
    required BuildContext context,
    required WidgetRef ref,
    required dynamic item,
    required dynamic alert,
    required String priority,
    required String message,
  }) {
    return ExpiryAlertCard(
      name: item.name,
      quantity: item.quantityLabel,
      message: message,
      priority: priority,
      category: item.category,

      // ======================================================
      // UPDATE
      // ======================================================

      onUpdate: () {
        final targetAlert = alert ??
            ExpiryAlert(
              id: item.id,
              userId: '',
              itemId: item.id,
              itemName: item.name,
              expiryDate: item.expiryDate ?? DateTime.now(),
              daysUntilExpiry:
                  ref.read(expiryServiceProvider).daysUntilExpiry(item) ?? 0,
              status: 'active',
              priority: priority,
              message: message,
              isRead: false,
              createdAt: DateTime.now(),
            );

        context.push(
          AppRoutes.editExpiryTracking,
          extra: targetAlert,
        );
      },

      // ======================================================
      // STOP TRACKING
      // ======================================================

      onStopTracking: () async {
        final confirm = await showStopTrackingDialog(context);

        if (confirm != true) {
          return;
        }

        try {
          // 1. Clear expiry date on the PantryItem so it immediately stops being tracked!
          final updatedItem = item.copyWith(clearExpiryDate: true);
          await ref
              .read(pantryItemsProvider.notifier)
              .updateItem(updatedItem);

          // 2. Delete alert if alert exists
          final alertId = alert?.id ?? item.id;
          await ref.read(deleteExpiryAlertProvider)(alertId);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Stopped tracking expiry for ${item.name}.',
                ),
              ),
            );
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to stop tracking: $error',
                ),
              ),
            );
          }
        }
      },
    );
  }


  // ==========================================================
  // SECTION HEADER
  // ==========================================================

  static Widget _sectionHeader({
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,

              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),

            const SizedBox(width: 8),

            Text(
              title,
              style: const TextStyle(
                color:
                    AppColors.darkGreen,
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),

        Text(
          '$count items',
          style: const TextStyle(
            color:
                AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}


// ============================================================
// NO EXPIRY CARD
// ============================================================

class _NoExpiryCard
    extends StatelessWidget {
  const _NoExpiryCard({
    required this.name,
    required this.quantity,
    required this.onTrack,
  });

  final String name;
  final String quantity;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stack = available < 340 || textScale > 1.25;

        final expiryButton = _trackExpiryButton(context);
        final wasteButton = _trackWasteButton(context);

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [expiryButton, const SizedBox(height: 12), wasteButton],
          );
        }

        return Row(
          children: [
            Expanded(child: expiryButton),
            const SizedBox(width: 12),
            Expanded(child: wasteButton),
          ],
        );
      },
    );
  }

  Widget _trackExpiryButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return FilledButton(
      key: const ValueKey('track-item-expiry-button'),
      style: FilledButton.styleFrom(
        backgroundColor: isDark
            ? colorScheme.primary
            : FreshPalette.primaryButton,
        foregroundColor: isDark ? colorScheme.onPrimary : FreshPalette.card,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: () {
        context.push(AppRoutes.addExpiryTracking);
      },
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_alarm_outlined, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text('Track Item Expiry', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _trackWasteButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? colorScheme.primary : FreshPalette.primaryButton;

    return OutlinedButton(
      key: const ValueKey('track-waste-button'),
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        backgroundColor: isDark ? colorScheme.surface : FreshPalette.card,
        side: BorderSide(color: accent),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: () {
        context.push(AppRoutes.wasteTracker);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_sweep_outlined, size: 20, color: accent),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('Track Waste', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}