import 'package:cloud_firestore/cloud_firestore.dart';

const wasteReasons = [
  'Expired',
  'Spoiled',
  'Not Used',
  'Cooked Too Much',
  'Other',
];
const wasteUnits = [
  'pcs',
  'kg',
  'g',
  'L',
  'ml',
  'bottle',
  'pack',
  'slice',
  'portion',
];

class FoodWasteRecord {
  const FoodWasteRecord({
    this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.reason,
    required this.estimatedValue,
    required this.wastedAt,
  });

  final String? id;
  final String itemName;
  final double quantity;
  final String unit;
  final String reason;
  final double estimatedValue;
  final DateTime wastedAt;

  void validate() {
    if (itemName.trim().isEmpty ||
        !quantity.isFinite ||
        quantity <= 0 ||
        !estimatedValue.isFinite ||
        estimatedValue < 0 ||
        !wasteUnits.contains(unit) ||
        !wasteReasons.contains(reason)) {
      throw ArgumentError('Invalid waste record.');
    }
  }

  FoodWasteRecord copyWith({
    String? id,
    String? itemName,
    double? quantity,
    String? unit,
    String? reason,
    double? estimatedValue,
    DateTime? wastedAt,
  }) => FoodWasteRecord(
    id: id ?? this.id,
    itemName: itemName ?? this.itemName,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    reason: reason ?? this.reason,
    estimatedValue: estimatedValue ?? this.estimatedValue,
    wastedAt: wastedAt ?? this.wastedAt,
  );

  Map<String, dynamic> toMap() {
    validate();
    return {
      'itemName': itemName.trim(),
      'quantity': quantity,
      'unit': unit,
      'reason': reason,
      'estimatedValue': estimatedValue,
      'wastedAt': Timestamp.fromDate(wastedAt),
    };
  }

  factory FoodWasteRecord.fromMap(String id, Map<String, dynamic> data) {
    final name = data['itemName'];
    final quantity = data['quantity'];
    final unit = data['unit'];
    final reason = data['reason'];
    final value = data['estimatedValue'];
    final date = data['wastedAt'];
    if (id.isEmpty ||
        name is! String ||
        quantity is! num ||
        unit is! String ||
        reason is! String ||
        value is! num ||
        date is! Timestamp) {
      throw const FormatException('Invalid waste record.');
    }
    final record = FoodWasteRecord(
      id: id,
      itemName: name,
      quantity: quantity.toDouble(),
      unit: unit,
      reason: reason,
      estimatedValue: value.toDouble(),
      wastedAt: date.toDate(),
    );
    try {
      record.validate();
    } on ArgumentError {
      throw const FormatException('Invalid waste record.');
    }
    return record;
  }
}
