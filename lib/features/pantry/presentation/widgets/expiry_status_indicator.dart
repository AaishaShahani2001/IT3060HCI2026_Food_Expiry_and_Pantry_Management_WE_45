import 'package:flutter/material.dart';

import '../../domain/utils/expiry_status.dart';

class ExpiryStatusIndicator extends StatelessWidget {
  const ExpiryStatusIndicator({
    required this.status,
    this.size = 11,
    this.showTooltip = true,
    super.key,
  });

  final ExpiryStatus status;
  final double size;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indicator = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: status.colorFor(colorScheme),
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.surfaceContainerHighest,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.18),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );

    if (!showTooltip) {
      return Semantics(label: status.semanticLabel, child: indicator);
    }

    return Semantics(
      label: status.semanticLabel,
      child: Tooltip(message: status.label, child: indicator),
    );
  }
}

/// Compact info button that reveals the expiry colour legend on tap.
class ExpiryStatusLegendButton extends StatelessWidget {
  const ExpiryStatusLegendButton({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ExpiryStatusLegendSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () => show(context),
      tooltip: 'Expiry indicators',
      icon: const Icon(Icons.info_outline_rounded, size: 20),
      color: colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}

class _ExpiryStatusLegendSheet extends StatelessWidget {
  const _ExpiryStatusLegendSheet();

  static const _statuses = [
    ExpiryStatus.fresh,
    ExpiryStatus.expiringSoon,
    ExpiryStatus.expired,
    ExpiryStatus.unknown,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Expiry indicators',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              ..._statuses.map(
                (status) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      ExpiryStatusIndicator(
                        status: status,
                        size: 10,
                        showTooltip: false,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status chip that uses colour, icon and text together.
class ExpiryStatusBadge extends StatelessWidget {
  const ExpiryStatusBadge({required this.status, super.key});

  final ExpiryStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = status.foregroundColorFor(colorScheme);
    return Semantics(
      label: status.semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: status.backgroundColorFor(colorScheme),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: foreground.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              status.badgeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
