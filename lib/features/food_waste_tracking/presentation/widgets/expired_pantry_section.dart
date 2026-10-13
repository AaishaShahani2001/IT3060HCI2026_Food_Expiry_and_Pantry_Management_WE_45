import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../providers/food_waste_provider.dart';
import '../providers/pantry_waste_provider.dart';
import 'waste_motion.dart';

class ExpiredPantrySection extends ConsumerWidget {
  const ExpiredPantrySection({super.key, required this.onRecord});
  final ValueChanged<PantryWasteSource>? onRecord;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(expiredWastePantryProvider);
    // Never render cached suggestions while loading a different UID.
    if (data.isLoading) return const SizedBox.shrink();
    if (data.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Pantry suggestions unavailable. You can still record waste manually.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final items = data.asData?.value ?? const <PantryWasteSource>[];
    if (items.isEmpty) return const SizedBox.shrink();
    // Recreate presentation state on account changes; never animate old-user
    // cards into the next account, or carry its selected category across.
    return _CategorizedExpiredItems(
      key: ValueKey(items.first.uid),
      items: items,
      onRecord: onRecord,
      now: ref.watch(wasteClockProvider)(),
    );
  }
}

class _CategorizedExpiredItems extends StatefulWidget {
  const _CategorizedExpiredItems({
    super.key,
    required this.items,
    required this.onRecord,
    required this.now,
  });
  final List<PantryWasteSource> items;
  final ValueChanged<PantryWasteSource>? onRecord;
  final DateTime now;
  @override
  State<_CategorizedExpiredItems> createState() =>
      _CategorizedExpiredItemsState();
}

class _CategorizedExpiredItemsState extends State<_CategorizedExpiredItems> {
  PantryCategory? _selected;

  @override
  void didUpdateWidget(covariant _CategorizedExpiredItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.items.any((source) => source.item.category == _selected)) {
      _selected = null;
    }
  }

  Widget _filter(
    BuildContext context,
    PantryCategory? category,
    PantryCategory? selected,
  ) {
    final active = category == selected;
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: wasteMotionDuration(context, 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: active ? colors.secondaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? colors.primary.withValues(alpha: 0.35)
              : colors.outlineVariant,
        ),
      ),
      child: Semantics(
        selected: active,
        child: TextButton(
          key: ValueKey('expired-filter-${category?.name ?? 'all'}'),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () => setState(() => _selected = category),
          child: AnimatedDefaultTextStyle(
            duration: wasteMotionDuration(context, 200),
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: active
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
            child: Text(category?.label ?? 'All'),
          ),
        ),
      ),
    );
  }

  String _expiredTiming(DateTime? expiry) {
    if (expiry == null) return 'Expired';
    final date = expiry.toLocal();
    final now = widget.now.toLocal();
    // Count calendar dates, not elapsed 24-hour periods across DST changes.
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
    return days > 0
        ? 'Expired $days ${days == 1 ? 'day' : 'days'} ago'
        : 'Expired';
  }

  Widget _itemCard(BuildContext context, PantryWasteSource source) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.brightness == Brightness.dark
        ? Colors.orange.shade200
        : Colors.brown.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WasteEntrance(
        key: ValueKey(source.item.firestoreId),
        child: WasteSurface(
          key: ValueKey('expired-card-${source.item.firestoreId}'),
          color: colors.surfaceContainerHighest,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      source.item.category.icon,
                      size: 22,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.item.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          source.item.quantityLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Expired',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: accent),
                    ),
                  ),
                  Text(
                    _expiredTiming(source.item.expiryDate),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WastePress(
                enabled: widget.onRecord != null,
                child: OutlinedButton.icon(
                  key: ValueKey('waste-pantry-${source.item.firestoreId}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: colors.primary,
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onPressed: widget.onRecord == null
                      ? null
                      : () => widget.onRecord!(source),
                  icon: const Icon(Icons.playlist_add, size: 20),
                  label: const Text('Record as Waste'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    // Pantry parses unavailable/unrecognized category data as Other. Keep all
    // known categories intact and only offer filters represented in this list.
    final categories = PantryCategory.values
        .where(
          (category) => items.any((source) => source.item.category == category),
        )
        .toList();
    final selected = categories.contains(_selected) ? _selected : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: WasteEntrance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expired Pantry Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Only record food you actually discarded.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${items.length} ${items.length == 1 ? 'item' : 'items'} may need attention',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _filter(context, null, selected),
                for (final category in categories)
                  _filter(context, category, selected),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: wasteMotionDuration(context, 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeInOut,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [
                  for (final old in previous)
                    ExcludeSemantics(child: IgnorePointer(child: old)),
                  ?current,
                ],
              ),
              child: Column(
                key: ValueKey(selected),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final category in categories)
                    if (selected == null || selected == category) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${category.label} (${items.where((source) => source.item.category == category).length})',
                          key: ValueKey('expired-group-${category.name}'),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      for (final source in items.where(
                        (source) => source.item.category == category,
                      ))
                        _itemCard(context, source),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
