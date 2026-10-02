import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';

import '../../../expiry/presentation/providers/expiry_provider.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import 'home_section_header.dart';

/// Home dashboard overview card for the user's pantry.
///
/// Displays real-time counts for Total Items and Expiring Soon items by
/// consuming the existing [pantrySummaryProvider] and [expirySummaryProvider].
class HomePantrySummaryCard extends ConsumerWidget {
  const HomePantrySummaryCard({super.key});

  static const backgroundImage = AssetImage('assets/images/food-storage.avif');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _PantrySummaryView();
  }
}

class _PantrySummaryView extends ConsumerStatefulWidget {
  const _PantrySummaryView();

  @override
  ConsumerState<_PantrySummaryView> createState() => _PantrySummaryViewState();
}

class _PantrySummaryViewState extends ConsumerState<_PantrySummaryView> {
  static const _radius = BorderRadius.all(Radius.circular(20));
  bool _imageFailed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch raw pantry items stream state to handle loading and error states gracefully
    final pantryAsync = ref.watch(pantryItemsProvider);
    final isLoading = pantryAsync.isLoading && !pantryAsync.hasValue;
    final hasError = pantryAsync.hasError && !pantryAsync.hasValue;

    // Reuse existing pantry and expiry providers to keep counts synchronized
    final pantrySummary = ref.watch(pantrySummaryProvider);
    final expirySummary = ref.watch(expirySummaryProvider);

    final totalCount = hasError ? 0 : pantrySummary.total;
    final expiringCount = hasError ? 0 : expirySummary.expiringSoon;
    final usePhoto = !_imageFailed;
    final fallbackColor = isDark ? FreshPalette.darkCard : FreshPalette.card;
    final onPhoto = FreshPalette.darkOnPrimary;
    final titleColor = usePhoto
        ? onPhoto
        : (isDark ? FreshPalette.darkHeading : FreshPalette.heading);
    final subtitleColor = usePhoto
        ? onPhoto.withValues(alpha: 0.9)
        : (isDark
              ? FreshPalette.darkSecondaryText
              : FreshPalette.secondaryText);
    final pantryIconBackground = isDark
        ? FreshPalette.selected
        : FreshPalette.primaryButton;
    final pantryIconBorder = isDark
        ? FreshPalette.highlight.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.62);
    final overlay = const Color(
      0xFF0E2F25,
    ).withValues(alpha: isDark ? 0.62 : 0.55);

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final shouldStack = textScale > 1.4 || screenWidth < 300;

    final totalBox = _PantryStatBox(
      icon: Icons.inventory_2_outlined,
      iconColor: isDark ? FreshPalette.highlight : FreshPalette.primaryButton,
      iconBgColor:
          (isDark ? FreshPalette.highlight : FreshPalette.primaryButton)
              .withValues(alpha: 0.14),
      bgColor: isDark
          ? FreshPalette.darkAccentSurface
          : FreshPalette.accentSurface,
      borderColor:
          (isDark ? FreshPalette.highlight : FreshPalette.primaryButton)
              .withValues(alpha: 0.2),
      count: totalCount,
      label: 'Total Items',
      isLoading: isLoading,
      isDark: isDark,
      imageAssetPath: 'assets/images/vector-pantry.avif',
      fallbackIcon: Icons.inventory_2_outlined,
    );

    final expiringBox = _PantryStatBox(
      icon: Icons.schedule_outlined,
      iconColor: AppColors.statusAmber,
      iconBgColor: AppColors.statusAmber.withValues(alpha: 0.15),
      bgColor: isDark ? const Color(0xFF2C2216) : AppColors.statusAmberBg,
      borderColor: AppColors.statusAmber.withValues(alpha: 0.25),
      count: expiringCount,
      label: 'Expiring Soon',
      isLoading: isLoading,
      isDark: isDark,
      imageAssetPath: 'assets/images/expiry-icon.jpg',
      fallbackIcon: Icons.schedule_outlined,
    );

    return Material(
      color: fallbackColor,
      borderRadius: _radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.pantry),
        borderRadius: _radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(
              color: usePhoto
                  ? onPhoto.withValues(alpha: 0.28)
                  : (isDark
                        ? FreshPalette.darkOutline.withValues(alpha: 0.6)
                        : FreshPalette.outline.withValues(alpha: 0.6)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (usePhoto)
                Positioned.fill(
                  child: Image(
                    image: HomePantrySummaryCard.backgroundImage,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (frame == null && !wasSynchronouslyLoaded) {
                            return ColoredBox(color: fallbackColor);
                          }
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 3,
                                  sigmaY: 3,
                                ),
                                child: child,
                              ),
                              ColoredBox(color: overlay),
                            ],
                          );
                        },
                    errorBuilder: (context, error, stackTrace) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_imageFailed) {
                          setState(() => _imageFailed = true);
                        }
                      });
                      return ColoredBox(color: fallbackColor);
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // PANTRY HEADER — Reusable HomeSectionHeader
                    HomeSectionHeader(
                      title: 'Your Pantry',
                      subtitle: 'Keep track of your food items',
                      assetPath: 'assets/images/food-pantry.png',
                      fallbackIcon: Icons.kitchen_outlined,
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconBgColor: pantryIconBackground,
                      iconBorderColor: pantryIconBorder,
                      iconSize: 36,
                      iconPadding: const EdgeInsets.all(6),
                      iconFit: BoxFit.contain,
                      semanticLabel: 'Your Pantry, view pantry items',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: subtitleColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // STATISTIC CARDS ROW OR COLUMN
                    if (shouldStack)
                      Column(
                        children: [
                          totalBox,
                          const SizedBox(height: 10),
                          expiringBox,
                        ],
                      )
                    else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: totalBox),
                            const SizedBox(width: 12),
                            Expanded(child: expiringBox),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact stat box used for Total Items and Expiring Soon metrics.
class _PantryStatBox extends StatelessWidget {
  const _PantryStatBox({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.bgColor,
    required this.borderColor,
    required this.count,
    required this.label,
    required this.isLoading,
    required this.isDark,
    required this.imageAssetPath,
    required this.fallbackIcon,
  });

  static const _radius = 14.0;

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color bgColor;
  final Color borderColor;
  final int count;
  final String label;
  final bool isLoading;
  final bool isDark;
  final String imageAssetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countColor = isDark ? FreshPalette.darkHeading : FreshPalette.heading;
    final labelColor = isDark
        ? FreshPalette.darkSecondaryText
        : FreshPalette.secondaryText;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _BlurredCardImage(
              assetPath: imageAssetPath,
              fallbackIcon: fallbackIcon,
              iconColor: iconColor,
              overlayColor: bgColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stat Icon Well
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(height: 10),

                // Count or Loading Indicator
                if (isLoading)
                  SizedBox(
                    height: 26,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    '$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      color: countColor,
                    ),
                  ),

                const SizedBox(height: 4),

                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
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

class _BlurredCardImage extends StatelessWidget {
  const _BlurredCardImage({
    required this.assetPath,
    required this.fallbackIcon,
    required this.iconColor,
    required this.overlayColor,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final Color iconColor;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widthCap = constraints.maxWidth * 0.42;
            final heightCap = constraints.maxHeight * 0.72;
            var side = widthCap < heightCap ? widthCap : heightCap;
            if (side > 62) side = 62;
            if (side < 40) side = 40;

            final tint = overlayColor.computeLuminance() < 0.45
                ? Color.lerp(overlayColor, Colors.white, 0.58)!
                : overlayColor;

            return Align(
              alignment: const Alignment(0.92, -0.05),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(tint, BlendMode.darken),
                    child: Image.asset(
                      assetPath,
                      width: side,
                      height: side,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      filterQuality: FilterQuality.medium,
                      cacheWidth: (side * 3).round(),
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox.square(
                          dimension: side,
                          child: Icon(
                            fallbackIcon,
                            size: side * 0.46,
                            color: iconColor.withValues(alpha: 0.45),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
