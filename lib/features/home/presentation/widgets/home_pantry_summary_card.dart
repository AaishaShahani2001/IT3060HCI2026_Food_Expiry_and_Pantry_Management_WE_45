import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';

import '../../../expiry/presentation/providers/expiry_provider.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';

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
  static const _radius = BorderRadius.all(Radius.circular(22));
  bool _imageFailed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pantryAsync = ref.watch(pantryItemsProvider);
    final isLoading = pantryAsync.isLoading && !pantryAsync.hasValue;
    final hasError = pantryAsync.hasError && !pantryAsync.hasValue;

    final pantrySummary = ref.watch(pantrySummaryProvider);
    final expirySummary = ref.watch(expirySummaryProvider);

    final totalCount = hasError ? 0 : pantrySummary.total;
    final expiringCount = hasError ? 0 : expirySummary.expiringSoon;
    final usePhoto = !_imageFailed;
    final fallbackColor = isDark ? FreshPalette.darkCard : FreshPalette.card;

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final shouldStack = textScale > 1.35 || screenWidth < 340;

    final tileColor = isDark ? const Color(0xFF1A2822) : Colors.white;
    final countColor = isDark ? FreshPalette.darkHeading : FreshPalette.heading;
    final labelColor = isDark
        ? FreshPalette.darkSecondaryText
        : FreshPalette.secondaryText;
    final onPhoto = FreshPalette.darkOnPrimary;

    final totalBox = _PantryStatTile(
      icon: Icons.inventory_2_outlined,
      iconColor: isDark ? FreshPalette.highlight : FreshPalette.primaryButton,
      iconBgColor: isDark
          ? FreshPalette.highlight.withValues(alpha: 0.16)
          : FreshPalette.accentSurface,
      tileColor: tileColor,
      countColor: countColor,
      labelColor: labelColor,
      count: totalCount,
      label: 'Total Items',
      isLoading: isLoading,
    );

    final expiringBox = _PantryStatTile(
      icon: Icons.schedule_outlined,
      iconColor: AppColors.statusAmber,
      iconBgColor: isDark
          ? AppColors.statusAmber.withValues(alpha: 0.18)
          : AppColors.statusAmberBg,
      tileColor: tileColor,
      countColor: countColor,
      labelColor: labelColor,
      count: expiringCount,
      label: 'Expiring Soon',
      isLoading: isLoading,
    );

    return Material(
      color: fallbackColor,
      elevation: 0,
      borderRadius: _radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.pantry),
        borderRadius: _radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E2F25).withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
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
                    alignment: const Alignment(0, -0.15),
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
                                  sigmaX: 1.6,
                                  sigmaY: 1.6,
                                ),
                                child: child,
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x8A12352A),
                                      Color(0xC012352A),
                                      Color(0xE60E2F25),
                                    ],
                                    stops: [0, 0.46, 1],
                                  ),
                                ),
                              ),
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
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      label: 'Your Pantry, view pantry items',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Your Pantry',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    letterSpacing: -0.2,
                                    color: usePhoto ? onPhoto : countColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Keep track of your food items',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    height: 1.2,
                                    color: usePhoto
                                        ? onPhoto.withValues(alpha: 0.84)
                                        : labelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _OpenMark(
                            color: usePhoto
                                ? onPhoto
                                : (isDark
                                      ? FreshPalette.highlight
                                      : FreshPalette.primaryButton),
                            filled: usePhoto,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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

class _OpenMark extends StatelessWidget {
  const _OpenMark({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: filled
            ? Colors.white.withValues(alpha: 0.16)
            : color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: filled
              ? Colors.white.withValues(alpha: 0.38)
              : color.withValues(alpha: 0.28),
        ),
      ),
      child: Icon(Icons.arrow_forward_rounded, size: 18, color: color),
    );
  }
}

/// Solid metric tile so the count stays readable over the pantry photo.
class _PantryStatTile extends StatelessWidget {
  const _PantryStatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.tileColor,
    required this.countColor,
    required this.labelColor,
    required this.count,
    required this.label,
    required this.isLoading,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color tileColor;
  final Color countColor;
  final Color labelColor;
  final int count;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: isLoading ? label : '$label, $count',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      SizedBox(
                        height: 18,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                iconColor,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$count',
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            color: countColor,
                          ),
                        ),
                      ),
                    const SizedBox(height: 1),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: labelColor,
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
