import 'package:flutter/material.dart';

import '../../../pantry/domain/models/pantry_item.dart';
import '../../../shopping_list/data/low_stock_suggestion_settings.dart';

class LowStockSuggestionSettingsCard extends StatelessWidget {
  const LowStockSuggestionSettingsCard({
    required this.settings,
    required this.onEnabledChanged,
    required this.onThresholdChanged,
    super.key,
  });

  final LowStockSuggestionSettings settings;
  final ValueChanged<bool> onEnabledChanged;
  final void Function(PantryCategory category, int threshold)
  onThresholdChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            secondary: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.inventory_2_outlined, color: colors.primary),
            ),
            title: const Text(
              'Low Stock Suggestions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Automatically suggest pantry items when their quantity becomes low.',
            ),
            value: settings.enabled,
            onChanged: onEnabledChanged,
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'Category Thresholds',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose how sensitive low-stock suggestions should be for each category.',
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Level 1 uses the normal Pantry low-stock level. Higher levels suggest items earlier.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < PantryCategory.values.length;
                  index++
                ) ...[
                  _ThresholdRow(
                    category: PantryCategory.values[index],
                    value: settings.thresholdFor(PantryCategory.values[index]),
                    enabled: settings.enabled,
                    onChanged: (value) =>
                        onThresholdChanged(PantryCategory.values[index], value),
                  ),
                  if (index < PantryCategory.values.length - 1)
                    Divider(color: colors.outlineVariant, height: 1),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({
    required this.category,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final PantryCategory category;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${category.label} low-stock level $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(category.icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(category.label)),
            IconButton(
              tooltip: 'Decrease ${category.label} low-stock level',
              visualDensity: VisualDensity.compact,
              onPressed: enabled && value > minimumLowStockThreshold
                  ? () => onChanged(value - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Increase ${category.label} low-stock level',
              visualDensity: VisualDensity.compact,
              onPressed: enabled && value < maximumLowStockThreshold
                  ? () => onChanged(value + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
