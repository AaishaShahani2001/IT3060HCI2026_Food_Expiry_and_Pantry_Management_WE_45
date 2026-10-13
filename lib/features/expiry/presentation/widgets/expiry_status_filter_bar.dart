import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../pantry/domain/utils/expiry_status.dart';
import '../providers/expiry_provider.dart';

class ExpiryStatusFilterBar extends StatelessWidget {
  const ExpiryStatusFilterBar({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final ExpiryStatusFilter selected;
  final ({int total, int expired, int expiringSoon, int fresh, int unknown})
  counts;
  final ValueChanged<ExpiryStatusFilter> onSelected;

  static const _filters = <ExpiryStatusFilter>[
    ExpiryStatusFilter.all,
    ExpiryStatusFilter.fresh,
    ExpiryStatusFilter.expiringSoon,
    ExpiryStatusFilter.expired,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _filters.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _ExpiryStatusLabel(
              filter: _filters[index],
              count: expiryStatusFilterCount(counts, _filters[index]),
              selected: _filters[index] == selected,
              onSelected: () => onSelected(_filters[index]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExpiryStatusLabel extends StatelessWidget {
  const _ExpiryStatusLabel({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final ExpiryStatusFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final selectedBackground = isDark
        ? colorScheme.primary
        : FreshPalette.selected;
    final selectedForeground = isDark
        ? colorScheme.onPrimary
        : FreshPalette.card;
    final unselectedBackground = isDark
        ? colorScheme.surfaceContainerHighest
        : FreshPalette.card;
    final unselectedForeground = isDark
        ? colorScheme.onSurface
        : FreshPalette.heading;
    final unselectedBorder = isDark
        ? colorScheme.outline
        : FreshPalette.highlight;
    final foreground = selected ? selectedForeground : unselectedForeground;

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel(filter, count),
      child: ExcludeSemantics(
        child: ChoiceChip(
          label: SizedBox(
            width: double.infinity,
            child: Text(
              '${_visibleLabel(filter)} $count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          selected: selected,
          showCheckmark: true,
          checkmarkColor: selectedForeground,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
            color: foreground,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
          selectedColor: selectedBackground,
          backgroundColor: unselectedBackground,
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return selectedBackground;
            }
            return unselectedBackground;
          }),
          elevation: 0,
          pressElevation: 0,
          side: BorderSide(
            color: selected ? selectedBackground : unselectedBorder,
            width: selected ? 1.6 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (_) => onSelected(),
        ),
      ),
    );
  }
}

String _semanticLabel(ExpiryStatusFilter filter, int count) {
  final items = count == 1 ? 'item' : 'items';
  return switch (filter) {
    ExpiryStatusFilter.all => 'Show all $count expiry $items',
    ExpiryStatusFilter.fresh => 'Show $count fresh expiry $items',
    ExpiryStatusFilter.expiringSoon => 'Show $count $items expiring soon',
    ExpiryStatusFilter.expired => 'Show $count expired $items',
    ExpiryStatusFilter.unknown => 'Show $count $items with no expiry date',
  };
}

String _visibleLabel(ExpiryStatusFilter filter) {
  return switch (filter) {
    ExpiryStatusFilter.all => 'All',
    ExpiryStatusFilter.fresh => ExpiryStatus.fresh.badgeLabel,
    ExpiryStatusFilter.expiringSoon => ExpiryStatus.expiringSoon.badgeLabel,
    ExpiryStatusFilter.expired => ExpiryStatus.expired.badgeLabel,
    ExpiryStatusFilter.unknown => 'No Expiry',
  };
}
