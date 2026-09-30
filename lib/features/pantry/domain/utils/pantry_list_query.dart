import '../models/pantry_item.dart';

/// Maximum cards shown on the Pantry dashboard preview.
const int kPantryDashboardPreviewLimit = 5;

/// How filtered pantry items are ordered for the dashboard and View All.
enum PantrySortOption {
  recentlyAdded,
  nameAz,
  nameZa;

  String get label {
    switch (this) {
      case PantrySortOption.recentlyAdded:
        return 'Recently added';
      case PantrySortOption.nameAz:
        return 'Name (A–Z)';
      case PantrySortOption.nameZa:
        return 'Name (Z–A)';
    }
  }
}

/// Pure list helpers shared by the dashboard preview and All Pantry Items.
///
/// These operate on the in-memory Firestore-backed collection. They never
/// write back to that list and never perform additional Firestore reads.
abstract final class PantryListQuery {
  /// Applies search, location, category and stock filters.
  ///
  /// The search query matches item name, category, or location.
  static List<PantryItem> applyFilters({
    required List<PantryItem> items,
    required String searchQuery,
    PantryLocation? location,
    PantryCategory? category,
    required StockLevelFilter stockLevel,
  }) {
    final query = searchQuery.trim().toLowerCase();
    return [
      for (final item in items)
        if (_matches(
          item,
          query: query,
          location: location,
          category: category,
          stockLevel: stockLevel,
        ))
          item,
    ];
  }

  /// Sorts a copy of [items]. Missing [PantryItem.createdAt] values are placed
  /// after items with a valid timestamp when using recently-added order.
  static List<PantryItem> sortItems(
    List<PantryItem> items,
    PantrySortOption sortOption,
  ) {
    final sorted = List<PantryItem>.from(items);
    switch (sortOption) {
      case PantrySortOption.recentlyAdded:
        sorted.sort(_compareRecentlyAdded);
      case PantrySortOption.nameAz:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case PantrySortOption.nameZa:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
    }
    return sorted;
  }

  /// Derive a five-item dashboard preview without modifying the
  /// complete Firestore-backed list used by View All and summary counts.
  static List<PantryItem> preview(
    List<PantryItem> filteredAndSortedItems, {
    int limit = kPantryDashboardPreviewLimit,
  }) {
    if (filteredAndSortedItems.length <= limit) {
      return List<PantryItem>.from(filteredAndSortedItems);
    }
    return filteredAndSortedItems.take(limit).toList();
  }

  static bool _matches(
    PantryItem item, {
    required String query,
    required PantryLocation? location,
    required PantryCategory? category,
    required StockLevelFilter stockLevel,
  }) {
    final matchesSearch = query.isEmpty || _matchesSearchQuery(item, query);
    final matchesLocation = location == null || item.location == location;
    final matchesCategory = category == null || item.category == category;
    final matchesStock = switch (stockLevel) {
      StockLevelFilter.all => true,
      StockLevelFilter.inStock => !item.isLowStock,
      StockLevelFilter.lowStock => item.isLowStock,
    };
    return matchesSearch && matchesLocation && matchesCategory && matchesStock;
  }

  /// Name, category, or location may match the typed query (OR).
  static bool _matchesSearchQuery(PantryItem item, String query) {
    return item.name.toLowerCase().contains(query) ||
        item.category.label.toLowerCase().contains(query) ||
        item.category.name.toLowerCase().contains(query) ||
        item.location.label.toLowerCase().contains(query) ||
        item.location.name.toLowerCase().contains(query);
  }

  static int _compareRecentlyAdded(PantryItem a, PantryItem b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }
}
