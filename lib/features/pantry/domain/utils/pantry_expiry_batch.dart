import '../models/pantry_item.dart';

/// Result returned by the duplicate dialog. Null from the dialog means cancel.
enum DuplicateItemAction { cancel, addSeparately, viewExisting, updateExisting }

/// What the form does after the dialog. Save runs once and does not ask again.
enum PantryDuplicateFollowUp { stay, saveOnce, openDetails, openEditor }

PantryDuplicateFollowUp followUpFor(DuplicateItemAction? action) {
  switch (action) {
    case null:
    case DuplicateItemAction.cancel:
      return PantryDuplicateFollowUp.stay;
    case DuplicateItemAction.addSeparately:
      return PantryDuplicateFollowUp.saveOnce;
    case DuplicateItemAction.viewExisting:
      return PantryDuplicateFollowUp.openDetails;
    case DuplicateItemAction.updateExisting:
      return PantryDuplicateFollowUp.openEditor;
  }
}

/// Blocks a second Save tap while the first submission or dialog is open.
class PantrySubmitLock {
  bool _held = false;

  bool tryAcquire() {
    if (_held) return false;
    _held = true;
    return true;
  }

  void release() {
    _held = false;
  }
}

/// Trims, lowercases, and collapses repeated spaces so " milk " matches "Milk".
String normalizePantryBatchName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Calendar-day comparison in local time. A missing date matches only another
/// missing date.
bool samePantryExpiryDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

String formatPantryExpiryDate(DateTime date) {
  final local = date.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String pantryBatchStatusLabel(PantryItem item) {
  final status = item.expiryStatus.label;
  final date = item.expiryDate;
  if (date == null) return status;
  return '$status · ${formatPantryExpiryDate(date)}';
}

String pantryBatchSummary(PantryItem item) {
  final expiry = item.expiryDate == null
      ? 'No expiry date'
      : 'Expires ${formatPantryExpiryDate(item.expiryDate!)}';
  return '${item.location.label} • ${item.quantityLabel} • $expiry';
}

/// Same product by name or by barcode. Expiry date is not part of this check.
bool isSamePantryProduct({
  required PantryItem existing,
  required String name,
  String? barcode,
}) {
  final sameName =
      normalizePantryBatchName(existing.name) ==
          normalizePantryBatchName(name) &&
      normalizePantryBatchName(name).isNotEmpty;
  final existingCode = existing.barcode?.trim() ?? '';
  final candidateCode = barcode?.trim() ?? '';
  final sameBarcode =
      existingCode.isNotEmpty &&
      candidateCode.isNotEmpty &&
      existingCode == candidateCode;
  return sameName || sameBarcode;
}

/// Same product, storage place, unit, and calendar expiry day.
bool isSamePantryBatch({
  required PantryItem existing,
  required String name,
  required PantryLocation location,
  required PantryUnit unit,
  DateTime? expiryDate,
  String? barcode,
}) {
  return isSamePantryProduct(
        existing: existing,
        name: name,
        barcode: barcode,
      ) &&
      existing.location == location &&
      existing.unit == unit &&
      samePantryExpiryDay(existing.expiryDate, expiryDate);
}

class PantryMatchChoice {
  const PantryMatchChoice({
    required this.item,
    required this.exactBatch,
    required this.score,
  });

  final PantryItem item;
  final bool exactBatch;
  final int score;
}

class PantryProductLookup {
  const PantryProductLookup(this.matches);

  final List<PantryMatchChoice> matches;

  bool get isEmpty => matches.isEmpty;

  /// More than one item shares the top score, so View Existing must ask.
  bool get needsChoice {
    if (matches.length < 2) return false;
    final top = matches.first.score;
    return matches.where((match) => match.score == top).length > 1;
  }

  PantryMatchChoice? get preferred {
    if (matches.isEmpty || needsChoice) return null;
    return matches.first;
  }
}

/// Same-product items in [items], ranked so an exact batch outranks a
/// different expiry or location. [items] must already be one pantry.
PantryProductLookup lookupPantryProducts(
  Iterable<PantryItem> items, {
  required String name,
  required PantryLocation location,
  required PantryUnit unit,
  DateTime? expiryDate,
  String? barcode,
  String? excludeItemId,
}) {
  final matches = <PantryMatchChoice>[];
  for (final item in items) {
    if (_excluded(item, excludeItemId)) continue;
    if (!isSamePantryProduct(existing: item, name: name, barcode: barcode)) {
      continue;
    }
    final exact = isSamePantryBatch(
      existing: item,
      name: name,
      location: location,
      unit: unit,
      expiryDate: expiryDate,
      barcode: barcode,
    );
    matches.add(
      PantryMatchChoice(
        item: item,
        exactBatch: exact,
        score: _score(item, location: location, unit: unit, exact: exact),
      ),
    );
  }
  matches.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.item.id.compareTo(b.item.id);
  });
  return PantryProductLookup(matches);
}

int _score(
  PantryItem item, {
  required PantryLocation location,
  required PantryUnit unit,
  required bool exact,
}) {
  if (exact) return 300;
  if (item.location == location && item.unit == unit) return 200;
  if (item.location == location) return 100;
  if (item.unit == unit) return 50;
  return 10;
}

bool _excluded(PantryItem item, String? excludeItemId) {
  if (excludeItemId == null || excludeItemId.trim().isEmpty) return false;
  if (item.id == excludeItemId) return true;
  final firestoreId = item.firestoreId;
  return firestoreId != null && firestoreId == excludeItemId;
}
