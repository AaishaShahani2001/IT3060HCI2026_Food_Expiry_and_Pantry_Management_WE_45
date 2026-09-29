import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';

import '../../domain/repositories/expiry_repository.dart';

import '../providers/expiry_provider.dart';

import '../widgets/expiry_summary_card.dart';
import '../widgets/expiry_alert_card.dart';
import '../widgets/stop_tracking_dialog.dart';
import '../widgets/empty_expiry_state.dart';

class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(expirySummaryProvider);

    final smartItems = ref.watch(smartAlertItemsProvider);

    final expiryService = ref.read(expiryServiceProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // --------------------------------------------------
      // APP BAR
      // --------------------------------------------------
      appBar: AppBar(
        elevation: 0,

        title: const Text(
          'Expiry Monitoring',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            tooltip: 'Expiry Notifications',
            onPressed: () {
              context.push(AppRoutes.expiryNotifications);
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 26),
          ),
        ],
      ),

      body: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Monitor your products and take action before food expires.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // EXPIRY SUMMARY
            // --------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Expired',
                    value: summary.expired.toString(),
                    icon: Icons.error_outline_rounded,
                    color: AppColors.statusRed,
                    backgroundColor: _statusSurface(
                      colorScheme,
                      AppColors.statusRed,
                      AppColors.statusRedBg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    title: 'Expiring Soon',
                    value: summary.expiringSoon.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.statusOrange,
                    backgroundColor: _statusSurface(
                      colorScheme,
                      AppColors.statusOrange,
                      AppColors.statusOrangeBg,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Fresh',
                    value: summary.fresh.toString(),
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.statusFresh,
                    backgroundColor: _statusSurface(
                      colorScheme,
                      AppColors.statusFresh,
                      AppColors.statusFreshBg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    title: 'Unknown',
                    value: summary.unknown.toString(),
                    icon: Icons.help_outline_rounded,
                    color: colorScheme.onSurfaceVariant,
                    backgroundColor: _statusSurface(
                      colorScheme,
                      colorScheme.onSurfaceVariant,
                      colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // SMART ALERTS HEADER
            // --------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Smart Alerts',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                if (smartAlertItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusSurface(
                        colorScheme,
                        AppColors.statusRed,
                        AppColors.statusRedBg,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${smartAlertItems.length} alerts',
                      style: const TextStyle(
                        color: AppColors.statusRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // SMART ALERT ITEMS / USE FIRST
            // --------------------------------------------------
            if (smartAlertItems.isEmpty)
              const _EmptyState(
                message: 'No products require expiry attention.',
              )
            else
              ...smartAlertItems.map((item) {
                final days = expiryService.daysUntilExpiry(item);

                final priority = expiryService.alertPriority(item);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExpiryAlertCard(
                    productName: item.name,
                    quantity: item.quantityLabel,
                    message: expiryService.expiryMessage(item),
                    priority: priority,
                    daysUntilExpiry: days,
                  ),
                );
              }),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // ALL PRODUCTS
            // --------------------------------------------------
            Text(
              'All Products',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (allItems.isEmpty)
              const _EmptyState(message: 'No pantry products found.')
            else
              ...allItems.map((item) {
                final days = expiryService.daysUntilExpiry(item);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProductExpiryCard(
                    productName: item.name,
                    quantity: item.quantityLabel,
                    expiryMessage: expiryService.expiryMessage(item),
                    status: item.expiryStatus.label,
                    daysUntilExpiry: days,
                  ),
                );
              }),
          ],
        ),

        onPressed: () {
          context.push(AppRoutes.addExpiryTracking);
        },
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          const Text(
            "Monitor your products and take action before food expires.",

            style: TextStyle(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ExpirySummaryCard(
                  title: "Expired",

                  value: summary.expired.toString(),

                  icon: Icons.error_outline,

                  color: AppColors.statusRed,

                  backgroundColor: AppColors.statusRedBg,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

  @override
  Widget build(BuildContext context) {
    final isCritical = priority == 'critical';

    final isHigh = priority == 'high';

    final colorScheme = Theme.of(context).colorScheme;

    final color = isCritical
        ? AppColors.statusRed
        : isHigh
        ? AppColors.statusOrange
        : AppColors.statusAmber;

    final backgroundColor = _statusSurface(
      colorScheme,
      color,
      isCritical
          ? AppColors.statusRedBg
          : isHigh
          ? AppColors.statusOrangeBg
          : AppColors.statusAmberBg,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCritical
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              color: color,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    _PriorityBadge(
                      priority: priority,
                      color: color,
                      backgroundColor: backgroundColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ExpirySummaryCard(
                  title: "No Expiry",

                  value: summary.unknown.toString(),

                Text(
                  quantity,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              const Text(
                "SMART ALERTS",

                style: TextStyle(
                  color: AppColors.darkGreen,

                  fontSize: 18,

                  fontWeight: FontWeight.bold,
                ),
              ),

                if (daysUntilExpiry != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    daysUntilExpiry! < 0
                        ? 'Requires immediate attention'
                        : 'Consider prioritizing this item',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 15),

          if (smartItems.isEmpty)
            const EmptyExpiryState(message: "No expiry alerts currently")
          else
            ...smartItems.map((item) {
              final alert = ExpiryAlert(
                id: item.id,

                userId: "",

                itemId: item.id,

                itemName: item.name,

  @override
  Widget build(BuildContext context) {
    final isExpired = daysUntilExpiry != null && daysUntilExpiry! < 0;

    final isSoon =
        daysUntilExpiry != null &&
        daysUntilExpiry! >= 0 &&
        daysUntilExpiry! <= 3;

    final colorScheme = Theme.of(context).colorScheme;

    final color = isExpired
        ? AppColors.statusRed
        : isSoon
        ? AppColors.statusOrange
        : AppColors.statusFresh;

    final backgroundColor = _statusSurface(
      colorScheme,
      color,
      isExpired
          ? AppColors.statusRedBg
          : isSoon
          ? AppColors.statusOrangeBg
          : AppColors.statusFreshBg,
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_outlined, color: color, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                status: "active",

                Text(
                  quantity,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),

                message: expiryService.expiryMessage(item),

                isRead: false,

                createdAt: DateTime.now(),
              );

              return ExpiryAlertCard(
                name: item.name,

                quantity: item.quantityLabel,

                message: expiryService.expiryMessage(item),

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.statusFresh,
            size: 40,
          ),

                onUpdate: () {
                  context.push(AppRoutes.editExpiryTracking, extra: alert);
                },

          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

Color _statusSurface(
  ColorScheme colorScheme,
  Color status,
  Color lightBackground,
) {
  if (colorScheme.brightness == Brightness.dark) {
    return status.withValues(alpha: 0.2);
  }
  return lightBackground;
}
