import 'package:flutter/material.dart';

import '../../../pantry/domain/models/pantry_item.dart';

class LowStockSuggestionsCard extends StatelessWidget {
  const LowStockSuggestionsCard({
    required this.items,
    required this.onAdd,
    required this.onDismiss,
    required this.onAddAll,
    required this.onDismissAll,
    required this.expanded,
    required this.onToggleExpanded,
    this.enabled = true,
    super.key,
  });

  final List<PantryItem> items;
  final ValueChanged<PantryItem> onAdd;
  final ValueChanged<PantryItem> onDismiss;
  final VoidCallback onAddAll;
  final VoidCallback onDismissAll;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: expanded
                  ? 'Collapse low-stock suggestions'
                  : 'Expand low-stock suggestions',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onToggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Low-stock suggestions (${items.length})',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 4),
              Text(
                'Add only what you plan to buy.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: enabled ? onDismissAll : null,
                    child: const Text('Dismiss All'),
                  ),
                  TextButton(
                    onPressed: enabled ? onAddAll : null,
                    child: const Text('Add All'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        _SuggestionRow(
                          item: items[index],
                          enabled: enabled,
                          onAdd: onAdd,
                          onDismiss: onDismiss,
                        ),
                        if (index < items.length - 1)
                          Divider(color: colors.outlineVariant, height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.item,
    required this.enabled,
    required this.onAdd,
    required this.onDismiss,
  });

  final PantryItem item;
  final bool enabled;
  final ValueChanged<PantryItem> onAdd;
  final ValueChanged<PantryItem> onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: '${item.name}, ${item.quantityLabel} remaining in pantry',
            excludeSemantics: true,
            child: Text(
              '${item.name} — ${item.isOutOfStock ? 'out of stock' : 'only ${item.quantityLabel} left'}',
              style: textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Dismiss ${item.name} suggestion',
          onPressed: enabled ? () => onDismiss(item) : null,
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          icon: const Icon(Icons.close),
        ),
        TextButton(
          onPressed: enabled ? () => onAdd(item) : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
