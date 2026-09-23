import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../food_waste_tracking/models/waste_summary.dart';
import '../../../food_waste_tracking/presentation/providers/food_waste_provider.dart';

/// Monthly food waste summary card displayed on the Home dashboard.
/// Displays the number of wasted items and estimated financial loss for the current month.
class HomeWasteSummaryCard extends ConsumerWidget {
  const HomeWasteSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dark-green card background matching FreshPalette
    final cardBg = isDark ? FreshPalette.selected : FreshPalette.primaryButton;
    final accentGreen = FreshPalette.highlight;

    final auth = ref.watch(wasteAuthUidProvider);
    final records = ref.watch(foodWasteProvider);
    final uid = auth.asData?.value;

    String itemCountText = '5 items';
    String estimatedLossText = 'Rs. 4,000';

    if (!auth.isLoading &&
        !auth.hasError &&
        uid != null &&
        ref.read(foodWasteRepositoryProvider).isCurrentUser(uid) &&
        !records.hasError) {
      records.whenData((items) {
        final summary = WasteSummary(
          items,
          WastePeriod.month,
          ref.read(wasteClockProvider)(),
        );
        if (items.isNotEmpty) {
          itemCountText =
              '${summary.count} ${summary.count == 1 ? 'item' : 'items'}';
          estimatedLossText = wasteMoney(summary.estimatedValue);
        }
      });
    }

    // Helper to open the full Food Waste Tracking screen
    void openWasteTracker() {
      context.push(AppRoutes.wasteTracker);
    }

    return Container(
      key: const ValueKey('home-waste-summary'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openWasteTracker,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row: Title & View All Action
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'This Month',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: openWasteTracker,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accentGreen,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: accentGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Statistics Section: Food Wasted | Estimated Loss
                Row(
                  children: [
                    // Food Wasted Stat
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: accentGreen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Food Wasted',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              itemCountText,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Subtle Vertical Divider
                    Container(
                      height: 36,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.white.withValues(alpha: 0.2),
                    ),

                    // Estimated Loss Stat
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 28,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Estimated Loss',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              estimatedLossText,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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

