import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../food_waste_tracking/presentation/screens/record_waste_screen.dart';
import '../../../pantry/presentation/utils/pantry_item_actions.dart';

/// Home shortcuts placed directly under the waste summary card.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('home-quick-actions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Quick Actions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              'Shortcuts',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _QuickActionCard(
                key: ValueKey('home-quick-add-item'),
                icon: Icons.add,
                lines: ['+ Add', 'Pantry Item'],
                label: 'Add Pantry Item',
                primary: true,
                onTap: _openAddItem,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _QuickActionCard(
                key: ValueKey('home-quick-scan-barcode'),
                icon: Icons.qr_code_scanner_outlined,
                lines: ['Scan', 'Barcode'],
                label: 'Scan Barcode',
                onTap: _openBarcodeScan,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _QuickActionCard(
                key: ValueKey('home-quick-shopping'),
                icon: Icons.shopping_cart_outlined,
                lines: ['Shopping', 'List'],
                label: 'Shopping List',
                onTap: _openShoppingList,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _QuickActionCard(
                key: ValueKey('home-quick-record-waste'),
                icon: Icons.delete_outline,
                lines: ['Record', 'Waste'],
                label: 'Record Waste',
                waste: true,
                onTap: _openRecordWaste,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

void _openAddItem(BuildContext context) {
  openPantryAddItem(context);
}

void _openShoppingList(BuildContext context) {
  context.go(AppRoutes.shopping);
}

void _openRecordWaste(BuildContext context) {
  Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => const RecordWasteScreen()));
}

/// The app has no barcode scanner screen or route. Keep the shortcut
/// tappable without adding a new screen.
void _openBarcodeScan(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Barcode scanning is not available yet.')),
  );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    super.key,
    required this.icon,
    required this.lines,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.waste = false,
  });

  final IconData icon;
  final List<String> lines;
  final String label;
  final void Function(BuildContext context) onTap;
  final bool primary;
  final bool waste;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = primary
        ? colorScheme.primary
        : (isDark ? FreshPalette.darkCard : FreshPalette.card);
    final foreground = primary ? colorScheme.onPrimary : colorScheme.onSurface;
    final iconColor = primary
        ? colorScheme.onPrimary
        : waste
        ? colorScheme.error
        : colorScheme.onSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('$label-tap'),
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          button: true,
          label: label,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: primary
                  ? null
                  : Border.all(
                      color: isDark
                          ? FreshPalette.darkOutline
                          : FreshPalette.outline,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final line in lines)
                        Text(
                          line,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                fontSize: 11,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
