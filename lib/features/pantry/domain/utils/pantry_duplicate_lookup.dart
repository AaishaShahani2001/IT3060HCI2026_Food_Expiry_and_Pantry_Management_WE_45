import '../models/pantry_item.dart';

/// Trimmed, case-insensitive name match used by the mock repository and the
/// live pantry notifier. Swap the item source for a Firestore query later.
PantryItem? lookupDuplicatePantryItemByName(
  Iterable<PantryItem> items,
  String name, {
  String? excludeItemId,
}) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  for (final item in items) {
    if (_isExcluded(item, excludeItemId)) continue;
    if (item.name.trim().toLowerCase() == normalized) {
      return item;
    }
  }
  return null;
}

bool _isExcluded(PantryItem item, String? excludeItemId) {
  if (excludeItemId == null || excludeItemId.trim().isEmpty) return false;
  if (item.id == excludeItemId) return true;
  final firestoreId = item.firestoreId;
  return firestoreId != null && firestoreId == excludeItemId;
}
