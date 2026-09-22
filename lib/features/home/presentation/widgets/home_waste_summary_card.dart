import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../food_waste_tracking/models/waste_summary.dart';
import '../../../food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'summary_card.dart';

/// Reuses the tracker state; rebuilding Home never starts a separate query.
class HomeWasteSummaryCard extends ConsumerWidget {
  const HomeWasteSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(wasteAuthUidProvider);
    final records = ref.watch(foodWasteProvider);
    final uid = auth.asData?.value;
    final String value;
    if (auth.isLoading) {
      value = 'Loading waste summary...';
    } else if (auth.hasError ||
        uid == null ||
        !ref.read(foodWasteRepositoryProvider).isCurrentUser(uid)) {
      value = 'Tap to view';
    } else if (records.hasError) {
      // Automatic retries can carry an error inside AsyncLoading.
      value = 'Tap to view';
    } else {
      value = records.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => 'Loading waste summary...',
        error: (_, _) => 'Tap to view',
        data: (items) {
          final summary = WasteSummary(
            items,
            WastePeriod.week,
            ref.read(wasteClockProvider)(),
          );
          if (items.isEmpty) return 'No waste recorded yet';
          if (summary.count == 0) return 'No waste recorded this week';
          return '${summary.count} ${summary.count == 1 ? 'item' : 'items'} wasted\n${wasteMoney(summary.estimatedValue)} this week';
        },
      );
    }
    return SummaryCard(
      key: const ValueKey('home-waste-summary'),
      title: 'Waste Tracker',
      value: value,
      icon: Icons.eco_outlined,
      onTap: () => context.push(AppRoutes.wasteTracker),
    );
  }
}
