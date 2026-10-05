import 'package:flutter/material.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_summary.dart';
import 'waste_motion.dart';

class WasteRecordTile extends StatelessWidget {
  const WasteRecordTile({
    super.key,
    required this.record,
    required this.now,
    this.onEdit,
    this.onDelete,
    this.onNotWasted,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });
  final FoodWasteRecord record;
  final DateTime now;
  Color get _accent => switch (record.reason) {
    'Expired' => Colors.deepOrange.shade700,
    'Spoiled' => Colors.amber.shade900,
    'Cooked Too Much' => Colors.brown.shade600,
    _ => Colors.grey.shade600,
  };
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onNotWasted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 1,
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerLow,
    shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
        width: selected ? 2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(width: 3, height: 36, color: _accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.itemName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${wasteNumber(record.quantity)} ${record.unit} • ${record.reason}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (record.isAutomaticExpiry) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Auto-recorded from expired Pantry stock',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${wasteMoney(record.estimatedValue)} • ${wasteRelativeDate(record.wastedAt, now)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (onEdit != null || onDelete != null || onNotWasted != null)
              WastePress(
                child: PopupMenuButton<String>(
                  tooltip: 'Actions for ${record.itemName}',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit?.call();
                      case 'delete':
                        onDelete?.call();
                      case 'not-wasted':
                        onNotWasted?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    if (onNotWasted != null)
                      const PopupMenuItem(
                        value: 'not-wasted',
                        child: Text('Not Wasted'),
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
