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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.inventory_2_outlined,
                color: colors.primary,
              ),
              title: const Text('Low Stock Suggestions'),
              subtitle: const Text(
                'Automatically suggest pantry items when their quantity becomes low.',
              ),
              value: settings.enabled,
              onChanged: onEnabledChanged,
            ),
            const SizedBox(height: 8),
            Text(
              'Suggest items when quantity is at or below:',
              style: textTheme.titleSmall?.copyWith(
                color: settings.enabled
                    ? colors.onSurface
                    : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Level 1 keeps the Pantry default: 100 g/ml or 1 for other units.',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in PantryCategory.values)
              _ThresholdRow(
                category: category,
                value: settings.thresholdFor(category),
                enabled: settings.enabled,
                onChanged: (value) => onThresholdChanged(category, value),
              ),
          ],
        ),
      ),
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
      label: '${category.label} low-stock threshold $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(category.icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(category.label)),
            IconButton(
              tooltip: 'Decrease ${category.label} low-stock threshold',
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
              tooltip: 'Increase ${category.label} low-stock threshold',
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
