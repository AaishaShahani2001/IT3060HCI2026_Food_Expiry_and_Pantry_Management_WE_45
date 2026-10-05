import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/pantry_scope.dart';

/// Small Personal / Shared chip. Uses the household name when one is known.
class PantryScopeBadge extends StatelessWidget {
  const PantryScopeBadge({super.key, required this.scope});

  final PantryScope scope;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = scope.isShared
        ? (isDark ? FreshPalette.darkAccentSurface : FreshPalette.accentSurface)
        : colorScheme.surfaceContainerHighest;
    final foreground = scope.isShared
        ? (isDark ? FreshPalette.highlight : FreshPalette.primaryButton)
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        scope.badgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
