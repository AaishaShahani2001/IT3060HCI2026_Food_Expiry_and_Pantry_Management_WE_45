import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/pantry_providers.dart';

/// Card/List toggle stored in [pantryViewModeProvider] for the Pantry session.
class PantryViewModeToggle extends ConsumerWidget {
  const PantryViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(pantryViewModeProvider);
    final notifier = ref.read(pantryViewModeProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final containerBg = isDark
        ? FreshPalette.darkAccentSurface
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final borderColor = isDark ? FreshPalette.darkOutline : FreshPalette.outline;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            isSelected: viewMode == PantryViewMode.cards,
            icon: Icons.grid_view_rounded,
            tooltip: 'Card view',
            onPressed: () => notifier.setMode(PantryViewMode.cards),
            isDark: isDark,
          ),
          const SizedBox(width: 2),
          _ToggleButton(
            isSelected: viewMode == PantryViewMode.list,
            icon: Icons.view_list_rounded,
            tooltip: 'List view',
            onPressed: () => notifier.setMode(PantryViewMode.list),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.isSelected,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isDark,
  });

  final bool isSelected;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? FreshPalette.selected : FreshPalette.primaryButton;
    final activeIconColor = FreshPalette.highlight;
    final inactiveIconColor = isDark
        ? FreshPalette.darkSecondaryText
        : FreshPalette.secondaryText;

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 38,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? activeIconColor : inactiveIconColor,
            ),
          ),
        ),
      ),
    );
  }
}

