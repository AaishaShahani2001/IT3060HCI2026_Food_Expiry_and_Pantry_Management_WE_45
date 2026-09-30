import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../domain/repositories/expiry_repository.dart';
import '../providers/expiry_provider.dart';
import '../widgets/empty_expiry_state.dart';
import '../widgets/expiry_alert_card.dart';
import '../widgets/expiry_summary_card.dart';
import '../widgets/stop_tracking_dialog.dart';

class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(expirySummaryProvider);
    final smartItems = ref.watch(smartAlertItemsProvider);
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
        actions: [
          IconButton(
            tooltip: 'Expiry Notifications',
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.darkGreen,
            ),
            onPressed: () {
              context.push(AppRoutes.expiryNotifications);
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const ExpiryTrackingActions(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Monitor your products and take action before food expires.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ExpirySummaryCard(
                  title: 'Expired',
                  value: summary.expired.toString(),
                  icon: Icons.error_outline,
                  color: AppColors.statusRed,
                  backgroundColor: AppColors.statusRedBg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ExpirySummaryCard(
                  title: 'Expiring Soon',
                  value: summary.expiringSoon.toString(),
                  icon: Icons.warning,
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
                child: ExpirySummaryCard(
                  title: 'Fresh',
                  value: summary.fresh.toString(),
                  icon: Icons.check_circle,
                  color: AppColors.statusFresh,
                  backgroundColor: AppColors.statusFreshBg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ExpirySummaryCard(
                  title: 'No Expiry',
                  value: summary.unknown.toString(),
                  icon: Icons.help_outline,
                  color: AppColors.textSecondary,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SMART ALERTS',
                style: TextStyle(
                  color: AppColors.darkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${smartItems.length} alerts',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (smartItems.isEmpty)
            const EmptyExpiryState(message: 'No expiry alerts currently')
          else
            ...smartItems.map((item) {
              final user = FirebaseAuth.instance.currentUser;
              final existing = savedAlertsMap[item.id];
              final alert = ExpiryAlert(
                id: item.id,
                userId: '',
                itemId: item.id,
                itemName: item.name,
                expiryDate: item.expiryDate ?? DateTime.now(),
                daysUntilExpiry: expiryService.daysUntilExpiry(item) ?? 0,
                status: 'active',
                priority: expiryService.alertPriority(item),
                message: expiryService.expiryMessage(item),
                isRead: false,
                createdAt: DateTime.now(),
              );

              return ExpiryAlertCard(
                name: item.name,
                quantity: item.quantityLabel,
                message: expiryService.expiryMessage(item),
                priority: expiryService.alertPriority(item),
                onUpdate: () {
                  context.push(AppRoutes.editExpiryTracking, extra: alert);
                },
                onStopTracking: () async {
                  final confirm = await showStopTrackingDialog(context);
                  if (confirm == true) {
                    await ref.read(stopTrackingProvider)(alert.id);
                  }
                },
              );
            }),
        ],
      ),
    );
  }
}

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
