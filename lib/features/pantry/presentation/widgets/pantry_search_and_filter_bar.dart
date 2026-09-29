import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/pantry_providers.dart';
import 'pantry_filter_bottom_sheet.dart';
import 'pantry_search_field.dart';

/// Search field plus filter action used on both Pantry screens.
class PantrySearchAndFilterBar extends StatelessWidget {
  const PantrySearchAndFilterBar({
    required this.controller,
    required this.filters,
    required this.onChanged,
    required this.onClearSearch,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final PantryFilterState filters;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: PantrySearchField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onClear: onClearSearch,
            ),
          ),
          IconButton(
            onPressed: () => PantryFilterBottomSheet.show(context),
            tooltip: 'Filter items',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Badge(
              isLabelVisible: filters.hasActiveFilters || filters.hasCustomSort,
              smallSize: 8,
              backgroundColor: AppColors.statusAmber,
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
