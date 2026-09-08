import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../providers/expiry_provider.dart';

class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(expirySummaryProvider);

    // All products, sorted by expiry urgency.
    final allItems = ref.watch(expiryItemsProvider);

    // Only products that actually require attention.
    final smartAlertItems = ref.watch(smartAlertItemsProvider);

    final expiryService = ref.read(expiryServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'Expiry Monitoring',
          style: TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: () async {
          await ref.read(pantryItemsProvider.notifier).refreshItems();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text(
              'Monitor your products and take action before food expires.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // Summary
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Expired',
                    value: summary.expired.toString(),
                    icon: Icons.error_outline_rounded,
                    color: AppColors.statusRed,
                    backgroundColor: AppColors.statusRedBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    title: 'Expiring Soon',
                    value: summary.expiringSoon.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.statusOrange,
                    backgroundColor: AppColors.statusOrangeBg,
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
                    backgroundColor: AppColors.statusFreshBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    title: 'Unknown',
                    value: summary.unknown.toString(),
                    icon: Icons.help_outline_rounded,
                    color: AppColors.textSecondary,
                    backgroundColor: AppColors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Smart Alerts heading
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Smart Alerts',
                    style: TextStyle(
                      color: AppColors.darkGreen,
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
                      color: AppColors.statusRedBg,
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

            // Smart Alerts
            if (smartAlertItems.isEmpty)
              const _EmptyState(
                message: 'No products require expiry attention.',
              )
            else
              ...smartAlertItems.map(
                (item) {
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
                },
              ),

            const SizedBox(height: 18),

            // All Products
            const Text(
              'All Products',
              style: TextStyle(
                color: AppColors.darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (allItems.isEmpty)
              const _EmptyState(
                message: 'No pantry products found.',
              )
            else
              ...allItems.map(
                (item) {
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
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryAlertCard extends StatelessWidget {
  const _ExpiryAlertCard({
    required this.productName,
    required this.quantity,
    required this.message,
    required this.priority,
    required this.daysUntilExpiry,
  });

  final String productName;
  final String quantity;
  final String message;
  final String priority;
  final int? daysUntilExpiry;

  @override
  Widget build(BuildContext context) {
    final isCritical = priority == 'critical';
    final isHigh = priority == 'high';

    final color = isCritical
        ? AppColors.statusRed
        : isHigh
            ? AppColors.statusOrange
            : AppColors.statusAmber;

    final backgroundColor = isCritical
        ? AppColors.statusRedBg
        : isHigh
            ? AppColors.statusOrangeBg
            : AppColors.statusAmberBg;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
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
                        style: const TextStyle(
                          color: AppColors.darkGreen,
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
                const SizedBox(height: 5),
                Text(
                  quantity,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (daysUntilExpiry != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    daysUntilExpiry! < 0
                        ? 'Requires immediate attention'
                        : 'Consider prioritizing this item',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({
    required this.priority,
    required this.color,
    required this.backgroundColor,
  });

  final String priority;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (priority == 'none') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProductExpiryCard extends StatelessWidget {
  const _ProductExpiryCard({
    required this.productName,
    required this.quantity,
    required this.expiryMessage,
    required this.status,
    required this.daysUntilExpiry,
  });

  final String productName;
  final String quantity;
  final String expiryMessage;
  final String status;
  final int? daysUntilExpiry;

  @override
  Widget build(BuildContext context) {
    final isExpired = daysUntilExpiry != null && daysUntilExpiry! < 0;
    final isSoon = daysUntilExpiry != null &&
        daysUntilExpiry! >= 0 &&
        daysUntilExpiry! <= 3;

    final color = isExpired
        ? AppColors.statusRed
        : isSoon
            ? AppColors.statusOrange
            : AppColors.statusFresh;

    final backgroundColor = isExpired
        ? AppColors.statusRedBg
        : isSoon
            ? AppColors.statusOrangeBg
            : AppColors.statusFreshBg;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.cardBorder,
        ),
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
            child: Icon(
              Icons.inventory_2_outlined,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  quantity,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  expiryMessage,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.statusFresh,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}