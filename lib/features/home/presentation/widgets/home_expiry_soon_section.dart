import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../expiry/presentation/providers/expiry_provider.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../../pantry/presentation/screens/pantry_item_details_screen.dart';
import '../../../pantry/presentation/widgets/pantry_item_image.dart';

/// Compact Home preview of pantry items already classified as expiring soon.
class HomeExpirySoonSection extends ConsumerWidget {
  const HomeExpirySoonSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantryAsync = ref.watch(pantryItemsProvider);
    final service = ref.read(expiryServiceProvider);
    final items = service.sortByExpiryUrgency(
      ref.watch(expiringSoonItemsProvider),
    );

    final body = switch (pantryAsync) {
      AsyncLoading() => const _ExpirySoonStatus(
        message: 'Loading expiring items',
        showProgress: true,
      ),
      AsyncError() => const _ExpirySoonStatus(
        message: 'Couldn’t load expiring items',
      ),
      AsyncData() when items.isEmpty => const _ExpirySoonStatus(
        message: 'No items expiring soon',
        icon: Icons.event_available_outlined,
      ),
      AsyncData() => _ExpirySoonList(items: items),
    };

    return Column(
      key: const ValueKey('home-expiry-soon-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ExpirySoonHeader(),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

class _ExpirySoonHeader extends StatelessWidget {
  const _ExpirySoonHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Expiry Soon',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.expiry),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: colorScheme.primary,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('See All'),
              Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpirySoonStatus extends StatelessWidget {
  const _ExpirySoonStatus({
    required this.message,
    this.icon,
    this.showProgress = false,
  });

  final String message;
  final IconData? icon;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? FreshPalette.darkCard : FreshPalette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? FreshPalette.darkOutline.withValues(alpha: 0.6)
                : FreshPalette.outline.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            if (showProgress)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            else
              Icon(
                icon ?? Icons.cloud_off_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpirySoonList extends StatelessWidget {
  const _ExpirySoonList({required this.items});

  final List<PantryItem> items;

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - 40;
    final cardWidth = ((available - 30) / 4).clamp(76.0, 112.0);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final imageHeight = cardWidth * 0.7;
    final cardHeight = imageHeight + (72 * textScale);

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _ExpirySoonCard(
            item: items[index],
            width: cardWidth,
            imageHeight: imageHeight,
          );
        },
      ),
    );
  }
}

class _ExpirySoonCard extends ConsumerWidget {
  const _ExpirySoonCard({
    required this.item,
    required this.width,
    required this.imageHeight,
  });

  final PantryItem item;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = ref.read(expiryServiceProvider).daysUntilExpiry(item) ?? 0;
    final label = _daysLeftLabel(days);
    final urgent = days <= 1;

    return Semantics(
      button: true,
      label: '${item.name}, $label',
      child: SizedBox(
        width: width,
        child: Material(
          color: isDark ? FreshPalette.darkCard : FreshPalette.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PantryItemDetailsScreen(item: item),
                ),
              );
            },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? FreshPalette.darkOutline.withValues(alpha: 0.6)
                      : FreshPalette.outline.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PantryItemImage(
                    item: item,
                    width: width,
                    height: imageHeight,
                    iconSize: 28,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    backgroundColor: isDark
                        ? FreshPalette.darkAccentSurface
                        : FreshPalette.accentSurface,
                    iconColor: isDark
                        ? FreshPalette.highlight
                        : FreshPalette.primaryButton,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: urgent
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  height: 1.1,
                                  color: urgent
                                      ? AppColors.statusOrange
                                      : AppColors.statusAmber,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _daysLeftLabel(int days) {
  if (days <= 0) return 'Expires today';
  if (days == 1) return '1 day left';
  return '$days days left';
}
