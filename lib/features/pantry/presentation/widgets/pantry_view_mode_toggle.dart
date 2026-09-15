import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pantry_providers.dart';

/// Card/List toggle stored in [pantryViewModeProvider] for the Pantry session.
///
/// Selection is not inferred from colour alone: Material 3 [IconButton.isSelected]
/// uses a selected overlay, and each control has a tooltip (also used as the
/// semantic label).
class PantryViewModeToggle extends ConsumerWidget {
  const PantryViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(pantryViewModeProvider);
    final notifier = ref.read(pantryViewModeProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.onSurfaceVariant;
      }),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Card view',
          isSelected: viewMode == PantryViewMode.cards,
          onPressed: () => notifier.setMode(PantryViewMode.cards),
          icon: const Icon(Icons.grid_view_rounded, semanticLabel: 'Card view'),
          style: buttonStyle,
        ),
        IconButton(
          tooltip: 'List view',
          isSelected: viewMode == PantryViewMode.list,
          onPressed: () => notifier.setMode(PantryViewMode.list),
          icon: const Icon(Icons.view_list_rounded, semanticLabel: 'List view'),
          style: buttonStyle,
        ),
      ],
    );
  }
}
