import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../domain/expiry_alert_id.dart';
import '../../domain/repositories/expiry_repository.dart';
import '../../domain/services/expiry_service.dart';
import '../providers/expiry_provider.dart';
import '../widgets/empty_expiry_state.dart';
import '../widgets/expiry_item_card.dart';
import '../widgets/expiry_status_filter_bar.dart';
import '../widgets/expiry_summary_card.dart';
import '../widgets/stop_tracking_dialog.dart';

class ExpiryTrackingActions extends StatelessWidget {
  const ExpiryTrackingActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        return SizedBox(width: width, child: _actionRow(context, isDark));
      },
    );
  }

  Widget _actionRow(BuildContext context, bool isDark) {
    return Row(
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
              backgroundColor: isDark
                  ? FreshPalette.selected
                  : FreshPalette.primaryButton,
              foregroundColor: isDark
                  ? FreshPalette.darkOnPrimary
                  : FreshPalette.card,
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
              context.push(AppRoutes.expiryNotifications);
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _expiryContentMaxWidth),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Text(
                      'Monitor your products and take action before food expires.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: ExpirySummarySection(
                      expiredCount: summary.expired,
                      expiringSoonCount: summary.expiringSoon,
                      freshCount: summary.fresh,
                      noExpiryCount: summary.unknown,
                      selectedFilter: selectedFilter,
                      onSelected: (filter) {
                        ref
                            .read(expiryStatusFilterProvider.notifier)
                            .select(filter);
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  const SliverToBoxAdapter(child: ExpiryTrackingActions()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: ExpiryStatusFilterBar(
                      selected: selectedFilter,
                      counts: summary,
                      onSelected: (filter) {
                        ref
                            .read(expiryStatusFilterProvider.notifier)
                            .select(filter);
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (items.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyExpiryState(
                        message: _emptyMessage(selectedFilter, trackedCount),
                        detail:
                            selectedFilter == ExpiryStatusFilter.all ||
                                trackedCount == 0
                            ? 'Track a pantry item to monitor its expiry date.'
                            : null,
                        actionLabel:
                            selectedFilter == ExpiryStatusFilter.all ||
                                trackedCount == 0
                            ? null
                            : 'Show All',
                        onAction:
                            selectedFilter == ExpiryStatusFilter.all ||
                                trackedCount == 0
                            ? null
                            : () {
                                ref
                                    .read(expiryStatusFilterProvider.notifier)
                                    .select(ExpiryStatusFilter.all);
                              },
                      ),
                    )
                  else if (selectedFilter == ExpiryStatusFilter.unknown)
                    _expiryItemSliver(context, ref, expiryService, items)
                  else ...[
                    ..._prioritySlivers(
                      context,
                      ref,
                      expiryService,
                      title: 'EXPIRING SOON',
                      accent: AppColors.statusAmber,
                      items: [...groups.useFirst, ...groups.expiringSoon],
                    ),
                    ..._prioritySlivers(
                      context,
                      ref,
                      expiryService,
                      title: 'EXPIRED ITEMS',
                      badge: 'Action Needed',
                      accent: AppColors.statusRed,
                      badgeBackground: AppColors.statusRedBg,
                      items: groups.expired,
                    ),
                    ..._prioritySlivers(
                      context,
                      ref,
                      expiryService,
                      title: 'FRESH',
                      accent: AppColors.statusFresh,
                      items: groups.outsidePriority,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double _expiryContentMaxWidth = 960;

/// One column below 700px of card width. Two columns from 700px upward.
const double _expiryCardColumnBreakpoint = 700;

List<Widget> _prioritySlivers(
  BuildContext context,
  WidgetRef ref,
  ExpiryService expiryService, {
  required String title,
  required Color accent,
  required List<PantryItem> items,
  String? badge,
  Color? badgeBackground,
}) {
  if (items.isEmpty) return const [];

  final countLabel = items.length == 1 ? '1 item' : '${items.length} items';

  return [
    SliverToBoxAdapter(
      child: _ExpirySectionHeader(
        title: title,
        badge: badge,
        accent: accent,
        badgeBackground: badgeBackground,
        countLabel: countLabel,
      ),
    ),
    _expiryItemSliver(context, ref, expiryService, items),
  ];
}

Widget _expiryItemSliver(
  BuildContext context,
  WidgetRef ref,
  ExpiryService expiryService,
  List<PantryItem> items,
) {
  return SliverLayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.crossAxisExtent >= _expiryCardColumnBreakpoint;
      if (!twoColumns) {
        return SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _expiryItemCard(context, ref, expiryService, items[index]),
            );
          },
        );
      }

      final rowCount = (items.length / 2).ceil();
      return SliverList.builder(
        itemCount: rowCount,
        itemBuilder: (context, row) {
          final left = row * 2;
          final right = left + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _expiryItemCard(
                    context,
                    ref,
                    expiryService,
                    items[left],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: right < items.length
                      ? _expiryItemCard(
                          context,
                          ref,
                          expiryService,
                          items[right],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _expiryItemCard(
  BuildContext context,
  WidgetRef ref,
  ExpiryService expiryService,
  PantryItem item,
) {
  final days = expiryService.daysUntilExpiry(item);
  final message = days == null
      ? 'No expiry date'
      : expiryService.expiryMessage(item);

  return ExpiryItemCard(
    key: ValueKey(item.id),
    item: item,
    message: message,
    urgency: expiryCardUrgency(days),
    onUpdate: () {
      context.push(
        AppRoutes.editExpiryTracking,
        extra: _alertFor(item, expiryService),
      );
    },
    onStopTracking: () async {
      final confirm = await showStopTrackingDialog(
        context,
        itemName: item.name,
      );
      if (confirm != true || !context.mounted) return;

      try {
        await ref
            .read(pantryItemsProvider.notifier)
            .updateItem(item.copyWith(clearExpiryDate: true));
        await ref.read(deleteExpiryAlertProvider)(
          _alertFor(item, expiryService).id,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stopped tracking expiry for ${item.name}.')),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop tracking: $error')),
        );
      }
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
    ExpiryStatusFilter.unknown =>
      trackedCount == 0 ? 'No expiry items' : 'No items without an expiry date',
  };
}

ExpiryAlert _alertFor(PantryItem item, ExpiryService service) {
  final expiryDate = item.expiryDate ?? DateTime.now();
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ExpiryAlert(
    id: userId.isEmpty ? item.id : buildExpiryAlertId(userId, item.id),
    userId: userId,
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
}
