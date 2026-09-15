import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

/// Dashboard section title with a matching-count View All action.
///
/// Uses [GoRouter.push] so the Pantry dashboard stays on the stack and
/// search, location, filters, and sort are still held in Riverpod on pop.
class PantryRecentItemsHeader extends StatelessWidget {
  const PantryRecentItemsHeader({required this.matchingCount, super.key});

  final int matchingCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              'Pantry Recent Items',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (matchingCount > 0) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'View all $matchingCount pantry items',
              child: TextButton(
                onPressed: () => context.push(AppRoutes.pantryItems),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All ($matchingCount)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
