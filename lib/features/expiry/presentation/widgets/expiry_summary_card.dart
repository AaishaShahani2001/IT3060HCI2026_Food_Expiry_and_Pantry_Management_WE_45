import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../pantry/domain/utils/expiry_status.dart';
import '../providers/expiry_provider.dart';

/// Compact expiry-status summary card with a faded calendar icon.
class ExpirySummaryCard extends StatelessWidget {
  const ExpirySummaryCard({
    super.key,
    required this.label,
    required this.count,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.detail,
    this.selected = false,
    this.onTap,
    this.semanticLabel,
  });

  final String label;
  final int count;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String? detail;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark
        ? colorScheme.surfaceContainerHighest
        : FreshPalette.card;
    final headingColor = isDark ? colorScheme.onSurface : FreshPalette.heading;
    final secondaryColor = isDark
        ? colorScheme.onSurfaceVariant
        : FreshPalette.secondaryText;
    final background = Color.alphaBlend(
      accentColor.withValues(
        alpha: isDark ? (selected ? 0.30 : 0.18) : (selected ? 0.18 : 0.12),
      ),
      surface,
    );
    final borderColor = selected
        ? accentColor
        : accentColor.withValues(alpha: isDark ? 0.40 : 0.28);
    final iconAlpha = isDark ? 0.16 : 0.10;

    final card = Material(
      color: background,
      borderRadius: _radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: _radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: Stack(
              children: [
                Positioned(
                  right: -6,
                  bottom: -10,
                  child: IgnorePointer(
                    child: Icon(
                      icon,
                      size: 52,
                      color: accentColor.withValues(alpha: iconAlpha),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.22 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _itemCountLabel(count),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: headingColor,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryColor,
                          height: 1.2,
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      selected: onTap != null && selected,
      label: semanticLabel,
      child: ExcludeSemantics(child: card),
    );
  }
}

/// Four expiry summary cards in a responsive grid.
///
/// Counts are supplied by [expirySummaryProvider] so this widget does not
/// calculate expiry status itself.
class ExpirySummarySection extends StatelessWidget {
  const ExpirySummarySection({
    super.key,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.freshCount,
    required this.noExpiryCount,
    required this.selectedFilter,
    required this.onSelected,
  });

  final int expiredCount;
  final int expiringSoonCount;
  final int freshCount;
  final int noExpiryCount;
  final ExpiryStatusFilter selectedFilter;
  final ValueChanged<ExpiryStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final neutral = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : FreshPalette.secondaryText;
    final soonWindow = 'Within ${kExpiryExpiringSoonDays}d';

    final cards = <Widget>[
      ExpirySummaryCard(
        key: const ValueKey('expiry-summary-expired'),
        label: 'ALERT',
        count: expiredCount,
        description: 'Expired',
        icon: Icons.event_busy_outlined,
        accentColor: AppColors.statusRed,
        selected: selectedFilter == ExpiryStatusFilter.expired,
        semanticLabel: _showExpiredLabel(expiredCount),
        onTap: () => onSelected(ExpiryStatusFilter.expired),
      ),
      ExpirySummaryCard(
        key: const ValueKey('expiry-summary-expiring-soon'),
        label: 'SOON',
        count: expiringSoonCount,
        description: 'Expiring Soon',
        detail: soonWindow,
        icon: Icons.upcoming_outlined,
        accentColor: AppColors.statusAmber,
        selected: selectedFilter == ExpiryStatusFilter.expiringSoon,
        semanticLabel: _showSoonLabel(expiringSoonCount),
        onTap: () => onSelected(ExpiryStatusFilter.expiringSoon),
      ),
      ExpirySummaryCard(
        key: const ValueKey('expiry-summary-fresh'),
        label: 'SAFE',
        count: freshCount,
        description: 'Fresh / Safe',
        icon: Icons.event_available_outlined,
        accentColor: AppColors.statusFresh,
        selected: selectedFilter == ExpiryStatusFilter.fresh,
        semanticLabel: _showFreshLabel(freshCount),
        onTap: () => onSelected(ExpiryStatusFilter.fresh),
      ),
      ExpirySummaryCard(
        key: const ValueKey('expiry-summary-no-expiry'),
        label: 'PANTRY',
        count: noExpiryCount,
        description: 'No Expiry',
        icon: Icons.calendar_month_outlined,
        accentColor: neutral,
        selected: selectedFilter == ExpiryStatusFilter.unknown,
        semanticLabel: _showNoExpiryLabel(noExpiryCount),
        onTap: () => onSelected(ExpiryStatusFilter.unknown),
      ),
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Expiry summary',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final columns = _summaryColumnCount(constraints.maxWidth, textScale);
          return _SummaryGrid(columns: columns, cards: cards);
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.columns, required this.cards});

  final int columns;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < cards.length; start += columns) {
      final end = start + columns > cards.length
          ? cards.length
          : start + columns;
      final rowCards = cards.sublist(start, end);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < rowCards.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: rowCards[index]),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          rows[index],
        ],
      ],
    );
  }
}

/// Phone widths use two columns. Very narrow panes and large text use one.
/// Wide layouts fit all four cards on a single row.
int _summaryColumnCount(double maxWidth, double textScale) {
  if (maxWidth < 300 || textScale >= 1.45) return 1;
  if (maxWidth >= 700 && textScale < 1.3) return 4;
  return 2;
}

String _itemCountLabel(int count) => count == 1 ? '1 item' : '$count items';

String _itemsWord(int count) => count == 1 ? 'item' : 'items';

String _showExpiredLabel(int count) =>
    'Show $count expired ${_itemsWord(count)}';

String _showSoonLabel(int count) =>
    'Show $count ${_itemsWord(count)} expiring soon';

String _showFreshLabel(int count) => 'Show $count fresh ${_itemsWord(count)}';

String _showNoExpiryLabel(int count) =>
    'Show $count ${_itemsWord(count)} with no expiry date';
