import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/pantry_item.dart';
import '../providers/pantry_providers.dart';
import '../screens/pantry_item_details_screen.dart';
import '../utils/pantry_item_actions.dart';
import 'pantry_item_card.dart';
import 'pantry_item_list_tile.dart';

/// Phone vs tablet breakpoint used for two-column pantry grids.
///
/// Below this width a single column stays readable and avoids quantity-control
/// overflow; at 700dp two cards fit without using a fixed pixel card width.
const double kPantryWideLayoutBreakpoint = 700;

class PantryItemHelpTargets {
  const PantryItemHelpTargets({
    required this.cardKey,
    required this.quantityKey,
    required this.actionsKey,
  });

  final GlobalKey cardKey;
  final GlobalKey quantityKey;
  final GlobalKey actionsKey;
}

/// Lazy card or list rendering for dashboard preview and All Pantry Items.
///
/// Uses slivers so large lists are not inflated at once. Item actions go
/// through the shared Firestore-backed [pantryItemsProvider].
class PantryItemsSliver extends ConsumerWidget {
  const PantryItemsSliver({
    required this.items,
    required this.viewMode,
    this.bottomPadding = 96,
    this.firstItemHelpTargets,
    super.key,
  });

  final List<PantryItem> items;
  final PantryViewMode viewMode;
  final double bottomPadding;
  final PantryItemHelpTargets? firstItemHelpTargets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;

    if (viewMode == PantryViewMode.list) {
      final isWide = width >= kPantryWideLayoutBreakpoint;
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 720 : width),
                child: _BoundPantryItem(
                  item: item,
                  index: index,
                  viewMode: PantryViewMode.list,
                ),
              ),
            );
          },
        ),
      );
    }

    // Grid View mode (2 columns on mobile, 3-4 columns on larger screens)
    final crossAxisCount = width >= 1100 ? 4 : (width >= 700 ? 3 : 2);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: kPantryCardExtent,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return _BoundPantryItem(
            item: item,
            index: index,
            viewMode: PantryViewMode.cards,
            helpTargets: index == 0 ? firstItemHelpTargets : null,
          );
        }, childCount: items.length),
      ),
    );
  }
}

class _BoundPantryItem extends ConsumerWidget {
  const _BoundPantryItem({
    required this.item,
    required this.index,
    required this.viewMode,
    this.helpTargets,
  });

  final PantryItem item;
  final int index;
  final PantryViewMode viewMode;
  final PantryItemHelpTargets? helpTargets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUpdating = ref.watch(
      pantryBusyItemIdsProvider.select((ids) => ids.contains(item.id)),
    );

    if (viewMode == PantryViewMode.list) {
      return PantryItemListTile(
        key: ValueKey(item.id),
        item: item,
        isUpdating: isUpdating,
        onTap: () => _openDetails(context, item),
        onEdit: () => openPantryItemEditor(context, item),
        onUsedUp: () => handlePantryUsedUp(
          context: context,
          ref: ref,
          item: item,
          originalIndex: index,
        ),
        onDelete: () =>
            handlePantryPermanentDelete(context: context, ref: ref, item: item),
        onIncrement: () => handlePantryQuantityDelta(
          context: context,
          ref: ref,
          item: item,
          delta: item.quantityStep,
        ),
        onDecrement: () => handlePantryQuantityDelta(
          context: context,
          ref: ref,
          item: item,
          delta: -item.quantityStep,
        ),
      );
    }

    final card = PantryItemCard(
      key: ValueKey(item.id),
      item: item,
      isUpdating: isUpdating,
      quantityHelpKey: helpTargets?.quantityKey,
      actionsHelpKey: helpTargets?.actionsKey,
      onTap: () => _openDetails(context, item),
      onEdit: () => openPantryItemEditor(context, item),
      onUsedUp: () => handlePantryUsedUp(
        context: context,
        ref: ref,
        item: item,
        originalIndex: index,
      ),
      onDelete: () =>
          handlePantryPermanentDelete(context: context, ref: ref, item: item),
      onIncrement: () => handlePantryQuantityDelta(
        context: context,
        ref: ref,
        item: item,
        delta: item.quantityStep,
      ),
      onDecrement: () => handlePantryQuantityDelta(
        context: context,
        ref: ref,
        item: item,
        delta: -item.quantityStep,
      ),
    );
    final cardKey = helpTargets?.cardKey;
    return cardKey == null ? card : KeyedSubtree(key: cardKey, child: card);
  }
}

Future<void> _openDetails(BuildContext context, PantryItem item) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => PantryItemDetailsScreen(item: item)),
  );
}
