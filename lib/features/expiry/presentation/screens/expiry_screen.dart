import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';

import '../providers/expiry_provider.dart';
import '../../domain/repositories/expiry_repository.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';

import '../widgets/expiry_summary_card.dart';
import '../widgets/expiry_alert_card.dart';
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
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final summary =
        ref.watch(expirySummaryProvider);

    final expiredItems =
        ref.watch(expiredItemsProvider);

    final expiringSoonItems =
        ref.watch(expiringSoonItemsProvider);

    final freshItems =
        ref.watch(freshItemsProvider);

    final unknownItems =
        ref.watch(unknownExpiryItemsProvider);

    // ----------------------------------------------------------
    // FIRESTORE ALERT MAP
    // ----------------------------------------------------------

    final alertByItemId =
        ref.watch(expiryAlertByItemIdProvider);

    final expiryService =
        ref.read(expiryServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,

      // ========================================================
      // APP BAR
      // ========================================================

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

        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.darkGreen,
            ),

            onPressed: () {
              context.push(
                AppRoutes.expiryNotifications,
              );
            },
          ),
        ],
      ),

      // ========================================================
      // CREATE
      // ========================================================

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          const ExpiryTrackingActions(),

      // ========================================================
      // BODY
      // ========================================================

      body: ListView(
        padding: const EdgeInsets.all(18),

        children: [

          const Text(
            'Monitor your products and take action before food expires.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 20),

          // ====================================================
          // SUMMARY ROW 1
          // ====================================================

          Row(
            children: [
              Expanded(
                child: ExpirySummaryCard(
                  title: 'Expired',
                  value:
                      summary.expired.toString(),
                  icon:
                      Icons.error_outline,
                  color:
                      AppColors.statusRed,
                  backgroundColor:
                      AppColors.statusRedBg,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ExpirySummaryCard(
                  title: 'Expiring Soon',
                  value:
                      summary.expiringSoon.toString(),
                  icon:
                      Icons.warning,
                  color:
                      AppColors.statusOrange,
                  backgroundColor:
                      AppColors.statusOrangeBg,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ====================================================
          // SUMMARY ROW 2
          // ====================================================

          Row(
            children: [
              Expanded(
                child: ExpirySummaryCard(
                  title: 'Fresh',
                  value:
                      summary.fresh.toString(),
                  icon:
                      Icons.check_circle,
                  color:
                      AppColors.statusFresh,
                  backgroundColor:
                      AppColors.statusFreshBg,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ExpirySummaryCard(
                  title: 'No Expiry',
                  value:
                      summary.unknown.toString(),
                  icon:
                      Icons.help_outline,
                  color:
                      AppColors.textSecondary,
                  backgroundColor:
                      Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // ====================================================
          // EXPIRED ITEMS
          // ====================================================

          _sectionHeader(
            title: 'EXPIRED ITEMS',
            count: expiredItems.length,
            color: AppColors.statusRed,
          ),

          const SizedBox(height: 12),

          if (expiredItems.isEmpty)
            const EmptyExpiryState(
              message: 'No expired items',
            )
          else
            ...expiredItems.map(
              (item) {
                final alert =
                    alertByItemId[item.id];

                return _buildTrackedCard(
                  context: context,
                  ref: ref,
                  item: item,
                  alert: alert,
                  priority: 'critical',
                  message:
                      expiryService.expiryMessage(
                    item,
                  ),
                );
              },
            ),

          const SizedBox(height: 25),

          // ====================================================
          // EXPIRING SOON
          // ====================================================

          _sectionHeader(
            title: 'EXPIRING SOON',
            count:
                expiringSoonItems.length,
            color:
                AppColors.statusOrange,
          ),

          const SizedBox(height: 12),

          if (expiringSoonItems.isEmpty)
            const EmptyExpiryState(
              message:
                  'No items expiring soon',
            )
          else
            ...expiringSoonItems.map(
              (item) {
                final alert =
                    alertByItemId[item.id];

                return _buildTrackedCard(
                  context: context,
                  ref: ref,
                  item: item,
                  alert: alert,
                  priority:
                      expiryService
                          .alertPriority(item),
                  message:
                      expiryService.expiryMessage(
                    item,
                  ),
                );
              },
            ),

          const SizedBox(height: 25),

          // ====================================================
          // FRESH ITEMS
          // ====================================================

          _sectionHeader(
            title: 'FRESH ITEMS',
            count: freshItems.length,
            color:
                AppColors.statusFresh,
          ),

          const SizedBox(height: 12),

          if (freshItems.isEmpty)
            const EmptyExpiryState(
              message: 'No fresh items',
            )
          else
            ...freshItems.map(
              (item) {
                final alert =
                    alertByItemId[item.id];

                return _buildTrackedCard(
                  context: context,
                  ref: ref,
                  item: item,
                  alert: alert,
                  priority: 'fresh',
                  message:
                      expiryService.expiryMessage(
                    item,
                  ),
                );
              },
            ),

          const SizedBox(height: 25),

          // ====================================================
          // NO EXPIRY
          // ====================================================

          _sectionHeader(
            title: 'NO EXPIRY DATE',
            count: unknownItems.length,
            color:
                AppColors.textSecondary,
          ),

          const SizedBox(height: 12),

          if (unknownItems.isEmpty)
            const EmptyExpiryState(
              message:
                  'All pantry items have expiry dates',
            )
          else
            ...unknownItems.map(
              (item) {
                return _NoExpiryCard(
                  name: item.name,
                  quantity:
                      item.quantityLabel,

                  // IMPORTANT:
                  // Only here does the user
                  // need to select/create tracking.

                  onTrack: () {
                    context.push(
                      AppRoutes.addExpiryTracking,
                    );
                  },
                );
              },
            ),

          const SizedBox(height: 110),
        ],
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: Colors.grey
              .withValues(alpha: 0.15),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.03),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,

            decoration:
                BoxDecoration(
              color: Colors.grey
                  .withValues(alpha: 0.08),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: const Icon(
              Icons.inventory_2_outlined,
              color:
                  AppColors.textSecondary,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  name,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF263238),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  quantity,
                  style:
                      const TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'No expiry date',
                  style:
                      TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          TextButton(
            onPressed: onTrack,

            child: const Text(
              'Track',
              style: TextStyle(
                color:
                    AppColors.primaryGreen,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}