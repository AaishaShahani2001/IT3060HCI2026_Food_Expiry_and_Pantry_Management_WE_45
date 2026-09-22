import 'package:flutter/material.dart';
import '../../models/waste_summary.dart';
import 'waste_motion.dart';

class WastePeriodSelector extends StatelessWidget {
  const WastePeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final WastePeriod selected;
  final ValueChanged<WastePeriod> onChanged;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final period in WastePeriod.values)
              Expanded(
                child: Semantics(
                  selected: selected == period,
                  child: AnimatedContainer(
                    duration: wasteMotionDuration(context, 200),
                    decoration: BoxDecoration(
                      color: selected == period
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        foregroundColor: selected == period
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: () => onChanged(period),
                      child: AnimatedDefaultTextStyle(
                        duration: wasteMotionDuration(context, 200),
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: selected == period
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: selected == period
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        child: Text(period.label, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
