import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

enum PantryEmptyStateType { noItems, noResults, error }

class PantryEmptyState extends StatelessWidget {
  const PantryEmptyState({
    required this.type,
    this.onPrimaryAction,
    this.onRetry,
    this.message,
    super.key,
  });

  final PantryEmptyStateType type;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _configForType(colorScheme, isDark, type);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: config.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, size: 42, color: config.iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? config.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (config.primaryLabel != null &&
                (onPrimaryAction != null || onRetry != null)) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onPrimaryAction ?? onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 48),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: Text(config.primaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _EmptyStateConfig _configForType(
    ColorScheme colorScheme,
    bool isDark,
    PantryEmptyStateType type,
  ) {
    switch (type) {
      case PantryEmptyStateType.noItems:
        return _EmptyStateConfig(
          icon: Icons.kitchen_outlined,
          iconColor: colorScheme.primary,
          backgroundColor: colorScheme.secondaryContainer,
          title: 'Your pantry is empty',
          message: 'Add your first item to start organizing your food.',
          primaryLabel: 'Add Your First Item',
        );
      case PantryEmptyStateType.noResults:
        return _EmptyStateConfig(
          icon: Icons.search_off_rounded,
          iconColor: AppColors.statusAmber,
          backgroundColor: isDark
              ? AppColors.statusAmber.withValues(alpha: 0.2)
              : AppColors.statusAmberBg,
          title: 'No matching pantry items',
          message: 'Try changing your search or filters.',
          primaryLabel: 'Clear Filters',
        );
      case PantryEmptyStateType.error:
        return _EmptyStateConfig(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.statusRed,
          backgroundColor: isDark
              ? AppColors.statusRed.withValues(alpha: 0.2)
              : AppColors.statusRedBg,
          title: 'Unable to load your pantry',
          message: 'Check your connection and try again.',
          primaryLabel: 'Retry',
        );
    }
  }
}

class _EmptyStateConfig {
  const _EmptyStateConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.message,
    this.primaryLabel,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String message;
  final String? primaryLabel;
}

class PantryLoadingState extends StatelessWidget {
  const PantryLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading your pantry...',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
