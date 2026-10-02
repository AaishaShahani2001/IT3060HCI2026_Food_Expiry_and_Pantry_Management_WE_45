import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../pantry/domain/utils/expiry_status.dart';

class ExpiryAlertCard extends StatelessWidget {
  const ExpiryAlertCard({
    super.key,
    required this.name,
    required this.quantity,
    required this.message,
    required this.status,
    this.badgeText,
    required this.onUpdate,
    required this.onStopTracking,
  });

  final String name;
  final String quantity;
  final String message;
  final ExpiryStatus status;

  /// Replaces the status badge text when a section needs its own label.
  final String? badgeText;
  final VoidCallback onUpdate;
  final VoidCallback onStopTracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = status.foregroundColorFor(colorScheme);
    final cardColor = isDark
        ? colorScheme.surfaceContainerHighest
        : FreshPalette.card;

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(quantity, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 5),
                Text(
                  badgeText ?? status.badgeLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: onUpdate,
                      child: const Text('Update'),
                    ),
                    TextButton(
                      onPressed: onStopTracking,
                      child: const Text('Stop Tracking'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
