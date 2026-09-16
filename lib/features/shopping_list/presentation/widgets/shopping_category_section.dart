import 'package:flutter/material.dart';

class ShoppingCategorySection extends StatelessWidget {
  const ShoppingCategorySection({
    super.key,
    required this.category,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String category;
  final int count;
  final bool expanded;
  final VoidCallback? onToggle;
  final List<Widget> children;

  IconData get _icon => switch (category) {
    'Dairy' => Icons.local_drink_outlined,
    'Vegetables' => Icons.eco_outlined,
    'Fruits' => Icons.spa_outlined,
    'Rice, Grains and Cereals' || 'Legumes' => Icons.grain,
    'Meat' => Icons.lunch_dining_outlined,
    'Seafood' => Icons.set_meal_outlined,
    'Bakery' || 'Baking' => Icons.bakery_dining_outlined,
    'Beverages' => Icons.local_cafe_outlined,
    'Snacks' => Icons.cookie_outlined,
    'Eggs' => Icons.egg_outlined,
    'Frozen Food' => Icons.ac_unit,
    _ => Icons.shopping_basket_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = category == 'Rice, Grains and Cereals' ? 'Grains' : category;
    return Material(
      color: colors.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Semantics(
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                color: colors.secondaryContainer.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: colors.onSurface),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$title ($count)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            for (final child in children) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: colors.outline.withValues(alpha: 0.4),
              ),
              child,
            ],
        ],
      ),
    );
  }
}
