import '../models/pantry_item.dart';

/// Currency display. Intermediate calculations stay unrounded.
String formatPantryRupees(double value) {
  final safe = !value.isFinite || value < 0 ? 0.0 : value;
  return 'Rs. ${safe.toStringAsFixed(2)}';
}

String priceEntryLabel(PantryUnit unit, PantryPriceType type) {
  if (type == PantryPriceType.totalPrice) return 'Total Price';
  return switch (unit) {
    PantryUnit.kg || PantryUnit.g => 'Price per kg',
    PantryUnit.liters || PantryUnit.ml => 'Price per L',
    PantryUnit.items => 'Price per item',
    PantryUnit.packs => 'Price per pack',
    PantryUnit.bottles => 'Price per bottle',
    PantryUnit.boxes => 'Price per box',
  };
}

/// Label used on item details for the stored amount.
String storedPriceDetailLabel(PantryUnit unit, PantryPriceType type) {
  if (type == PantryPriceType.totalPrice) return 'Total purchase price';
  return priceEntryLabel(unit, type);
}

String priceEntryHelper(
  PantryUnit unit,
  PantryPriceType type, {
  double? amount,
}) {
  if (type == PantryPriceType.totalPrice) {
    return 'Amount paid for the full quantity';
  }
  final reference = _referencePhrase(unit);
  if (amount == null || !amount.isFinite || amount < 0) {
    return 'Price for $reference';
  }
  return '${formatPantryRupees(amount)} for $reference';
}

String priceValidationMessage(PantryUnit unit, PantryPriceType type) {
  if (type == PantryPriceType.totalPrice) return 'Enter a valid total price.';
  return switch (unit) {
    PantryUnit.kg || PantryUnit.g => 'Enter a valid price per kg.',
    PantryUnit.liters || PantryUnit.ml => 'Enter a valid price per L.',
    PantryUnit.items => 'Enter a valid price per item.',
    PantryUnit.packs => 'Enter a valid price per pack.',
    PantryUnit.bottles => 'Enter a valid price per bottle.',
    PantryUnit.boxes => 'Enter a valid price per box.',
  };
}

String? validatePantryQuantity(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Quantity is required.';
  final parsed = double.tryParse(raw.trim());
  if (parsed == null || !parsed.isFinite) return 'Enter a valid number.';
  if (parsed <= 0) return 'Quantity must be greater than 0.';
  return null;
}

String? validatePantryPrice(
  String? raw, {
  required PantryUnit unit,
  required PantryPriceType type,
}) {
  final message = priceValidationMessage(unit, type);
  if (raw == null || raw.trim().isEmpty) return message;
  final parsed = double.tryParse(raw.trim());
  if (parsed == null || !parsed.isFinite || parsed < 0) return message;
  return null;
}

String totalPriceShareNote(PantryItem item) {
  return 'Based on ${item.quantityValueLabel} of the original ${item.originalQuantityLabel} remaining';
}

String _referencePhrase(PantryUnit unit) {
  return switch (unit) {
    PantryUnit.kg || PantryUnit.g => '1 kg',
    PantryUnit.liters || PantryUnit.ml => '1 L',
    PantryUnit.items => 'one item',
    PantryUnit.packs => 'one pack',
    PantryUnit.bottles => 'one bottle',
    PantryUnit.boxes => 'one box',
  };
}
