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
      children: [const _ExpirySoonHeader(), const SizedBox(height: 12), body],
    );
  }
}

class _ExpirySoonHeader extends StatefulWidget {
  const _ExpirySoonHeader();

  @override
  State<_ExpirySoonHeader> createState() => _ExpirySoonHeaderState();
}

class _ExpirySoonHeaderState extends State<_ExpirySoonHeader>
    with SingleTickerProviderStateMixin {
  static const _assetPath = 'assets/images/expiry_soon.png';
  static const _titleHeight = 36.0;
  static const _titleAspectRatio = 1112 / 360;

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnimation = Tween<double>(
      begin: 0.82,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  bool get _animationsAllowed {
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    final disabled =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !TickerMode.valuesOf(context).enabled;
    return !inTest && !disabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationsAllowed) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Semantics(
      container: true,
      header: true,
      label: 'Expiry Soon',
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _titleVisual(context),
          ),
        ),
      ),
    );

    return Row(
      children: [
        Flexible(child: title),
        const SizedBox(width: 8),
        Tooltip(
          message: 'View all expiring-soon items',
          child: Semantics(
            container: true,
            button: true,
            label: 'View all expiring-soon items',
            child: ExcludeSemantics(
              child: TextButton(
                onPressed: () => context.go(AppRoutes.expiry),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See All'),
                    Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleVisual(BuildContext context) {
    final titleWidth = _titleHeight * _titleAspectRatio;
    final image = Image.asset(
      _assetPath,
      width: titleWidth,
      height: _titleHeight,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SizedBox(
          width: titleWidth,
          height: _titleHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Expiry Soon',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? FreshPalette.darkHeading : FreshPalette.heading,
              ),
            ),
          ),
        );
      },
    );

    if (!_animationsAllowed) return image;

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          alignment: Alignment.centerLeft,
          scale: _scaleAnimation,
          child: image,
        ),
      ),
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
