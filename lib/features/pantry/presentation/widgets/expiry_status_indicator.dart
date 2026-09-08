import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
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
    final indicator = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: status.color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
    return IconButton(
      onPressed: () => show(context),
      tooltip: 'Expiry indicators',
      icon: const Icon(Icons.info_outline_rounded, size: 20),
      color: AppColors.textSecondary,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                  color: AppColors.heading,
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
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
