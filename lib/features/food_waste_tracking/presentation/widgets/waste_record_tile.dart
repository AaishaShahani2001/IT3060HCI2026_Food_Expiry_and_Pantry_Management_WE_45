import 'package:flutter/material.dart';
import '../../models/food_waste_record.dart';
import '../../models/waste_summary.dart';

class WasteRecordTile extends StatelessWidget {
  const WasteRecordTile({
    super.key,
    required this.record,
    this.onEdit,
    this.onDelete,
  });
  final FoodWasteRecord record;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
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
                ),
                const SizedBox(height: 4),
                Text(
                  '${wasteMoney(record.estimatedValue)} • ${wasteDate(record.wastedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Actions for ${record.itemName}',
              onSelected: (value) =>
                  value == 'edit' ? onEdit?.call() : onDelete?.call(),
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    ),
  );
}
