import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

enum PantryEmptyStateType { noItems, noResults, error }

class PantryEmptyState extends StatelessWidget {
  const PantryEmptyState({
    required this.type,
    this.onPrimaryAction,
    this.onRetry,
    super.key,
  });

  final PantryEmptyStateType type;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final config = _configForType(type);

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
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              config.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (config.primaryLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onPrimaryAction,
                style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
                child: Text(config.primaryLabel!),
              ),
            ],
            if (config.showRetry && onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }

  _EmptyStateConfig _configForType(PantryEmptyStateType type) {
    switch (type) {
      case PantryEmptyStateType.noItems:
        return const _EmptyStateConfig(
          icon: Icons.kitchen_outlined,
          iconColor: AppColors.primaryDark,
          backgroundColor: AppColors.softGreen,
          title: 'Your pantry is empty',
          message:
              'Start by adding your first food item to keep track of what you have at home.',
          primaryLabel: 'Add Your First Item',
        );
      case PantryEmptyStateType.noResults:
        return const _EmptyStateConfig(
          icon: Icons.search_off_rounded,
          iconColor: AppColors.statusAmber,
          backgroundColor: AppColors.statusAmberBg,
          title: 'No matching items',
          message:
              'Try adjusting your search or filters to find what you are looking for.',
          primaryLabel: 'Clear filters',
        );
      case PantryEmptyStateType.error:
        return const _EmptyStateConfig(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.statusRed,
          backgroundColor: AppColors.statusRedBg,
          title: 'Unable to load pantry',
          message:
              'Something went wrong while loading your items. Please try again.',
          showRetry: true,
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
    this.showRetry = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String message;
  final String? primaryLabel;
  final bool showRetry;
}

class PantryLoadingState extends StatelessWidget {
  const PantryLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Loading your pantry...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
