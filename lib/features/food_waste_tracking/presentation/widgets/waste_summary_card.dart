import 'package:flutter/material.dart';
import 'waste_motion.dart';

class WasteSummaryCard extends StatelessWidget {
  const WasteSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    this.compactValue = false,
    this.valueColor,
  });
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final bool compactValue;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return WasteSurface(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 18, color: colors.primary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: wasteMotionDuration(context),
              child: Text(
                value,
                key: ValueKey(value),
                style:
                    (compactValue
                            ? Theme.of(context).textTheme.titleSmall
                            : Theme.of(context).textTheme.titleLarge)
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
              ),
            ),
            const SizedBox(height: 6),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
