import 'package:flutter/material.dart';
import '../../models/waste_summary.dart';

class WastePeriodSelector extends StatelessWidget {
  const WastePeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final WastePeriod selected;
  final ValueChanged<WastePeriod> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final period in WastePeriod.values)
        ChoiceChip(
          label: Text(period.label),
          selected: selected == period,
          onSelected: (_) => onChanged(period),
        ),
    ],
  );
}
