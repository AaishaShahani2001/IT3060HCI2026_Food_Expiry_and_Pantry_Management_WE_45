import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/expiry_status.dart';

enum PantryLocation {
  refrigerator,
  freezer,
  pantry;

  String get label {
    switch (this) {
      case PantryLocation.refrigerator:
        return 'Refrigerator';
      case PantryLocation.freezer:
        return 'Freezer';
      case PantryLocation.pantry:
        return 'Pantry';
    }
  }

  IconData get icon {
    switch (this) {
      case PantryLocation.refrigerator:
        return Icons.kitchen_outlined;
      case PantryLocation.freezer:
        return Icons.ac_unit_rounded;
      case PantryLocation.pantry:
        return Icons.shelves;
    }
  }

  static PantryLocation fromStorage(String value) {
    final normalized = value.trim().toLowerCase();
    for (final location in PantryLocation.values) {
      if (location.name == normalized ||
          location.label.toLowerCase() == normalized) {
        return location;
      }
    }
    return PantryLocation.pantry;
  }
}

enum PantryCategory {
  dairy,
  meat,
  grains,
  fruits,
  vegetables,
  beverages,
  snacks,
  condiments,
  other;

  String get label {
    switch (this) {
      case PantryCategory.dairy:
        return 'Dairy';
      case PantryCategory.meat:
        return 'Meat';
      case PantryCategory.grains:
        return 'Grains';
      case PantryCategory.fruits:
        return 'Fruits';
      case PantryCategory.vegetables:
        return 'Vegetables';
      case PantryCategory.beverages:
        return 'Beverages';
      case PantryCategory.snacks:
        return 'Snacks';
      case PantryCategory.condiments:
        return 'Condiments';
      case PantryCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PantryCategory.dairy:
        return Icons.local_drink_rounded;
      case PantryCategory.meat:
        return Icons.kebab_dining_rounded;
      case PantryCategory.grains:
        return Icons.grain_rounded;
      case PantryCategory.fruits:
        return Icons.apple_rounded;
      case PantryCategory.vegetables:
        return Icons.eco_rounded;
      case PantryCategory.beverages:
        return Icons.local_cafe_outlined;
      case PantryCategory.snacks:
        return Icons.cookie_outlined;
      case PantryCategory.condiments:
        return Icons.water_drop_outlined;
      case PantryCategory.other:
        return Icons.inventory_2_outlined;
    }
  }

  static PantryCategory fromStorage(String value) {
    final normalized = value.trim().toLowerCase();
    for (final category in PantryCategory.values) {
      if (category.name == normalized ||
          category.label.toLowerCase() == normalized) {
        return category;
      }
    }
    return PantryCategory.other;
  }
}

enum PantryUnit {
  items,
  kg,
  g,
  liters,
  ml,
  packs,
  bottles;

  String get label {
    switch (this) {
      case PantryUnit.items:
        return 'Items';
      case PantryUnit.kg:
        return 'kg';
      case PantryUnit.g:
        return 'g';
      case PantryUnit.liters:
        return 'L';
      case PantryUnit.ml:
        return 'ml';
      case PantryUnit.packs:
        return 'Packs';
      case PantryUnit.bottles:
        return 'Bottles';
    }
  }

  String displayLabel(double quantity) {
    final isSingular = quantity == 1;
    switch (this) {
      case PantryUnit.items:
        return isSingular ? 'item' : 'items';
      case PantryUnit.kg:
        return 'kg';
      case PantryUnit.g:
        return 'g';
      case PantryUnit.liters:
        return 'L';
      case PantryUnit.ml:
        return 'ml';
      case PantryUnit.packs:
        return isSingular ? 'pack' : 'packs';
      case PantryUnit.bottles:
        return isSingular ? 'bottle' : 'bottles';
    }
  }

  static PantryUnit fromStorage(String value) {
    final normalized = value.trim().toLowerCase();
    for (final unit in PantryUnit.values) {
      if (unit.name == normalized || unit.label.toLowerCase() == normalized) {
        return unit;
      }
    }
    return PantryUnit.items;
  }
}

enum StockLevelFilter {
  all,
  inStock,
  lowStock;

  String get label {
    switch (this) {
      case StockLevelFilter.all:
        return 'All stock levels';
      case StockLevelFilter.inStock:
        return 'In stock';
      case StockLevelFilter.lowStock:
        return 'Low stock';
    }
  }
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.quantity,
    required this.unit,
    double? price,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
    this.firestoreId,
  }) : price = price ?? 0.0;

  final String id;
  final String name;
  final PantryCategory category;
  final PantryLocation location;
  final double quantity;
  final PantryUnit unit;

  /// Nullable so older in-memory items (hot reload) don't crash when read.
  final double? price;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Cloud Firestore document ID under users/{uid}/pantryItems/{itemId}.
  /// Null until the item has been written to Firestore.
  final String? firestoreId;

  /// True when this item can be updated or deleted in Cloud Firestore.
  bool get isConnectedToFirestore =>
      firestoreId != null && firestoreId!.trim().isNotEmpty;

  double get unitPrice {
    try {
      return price ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  String get priceLabel => 'Rs. ${unitPrice.toStringAsFixed(2)}';

  /// Minimum quantity threshold used for low-stock status.
  double get minQuantity {
    switch (unit) {
      case PantryUnit.g:
      case PantryUnit.ml:
        return 100;
      default:
        return 1;
    }
  }

  bool get isLowStock => quantity <= minQuantity;

  /// True when nothing remains. The item is kept; it is not auto-deleted.
  bool get isOutOfStock => quantity <= 0;

  /// Step size for quick +/- quantity controls.
  double get quantityStep {
    switch (unit) {
      case PantryUnit.kg:
      case PantryUnit.liters:
        return 0.5;
      case PantryUnit.g:
      case PantryUnit.ml:
        return 50;
      case PantryUnit.items:
      case PantryUnit.packs:
      case PantryUnit.bottles:
        return 1;
    }
  }

  String get quantityLabel {
    final formatted = _formatQuantity(quantity);
    return '$formatted ${unit.displayLabel(quantity)}';
  }

  String get quantityValueLabel => _formatQuantity(quantity);

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Returns a copy with quantity adjusted by [delta], never below zero.
  PantryItem withAdjustedQuantity(double delta) {
    final next = (quantity + delta).clamp(0.0, double.infinity);
    final rounded = double.parse(next.toStringAsFixed(2));
    return copyWith(quantity: rounded, updatedAt: DateTime.now());
  }

  ExpiryStatus get expiryStatus => ExpiryStatusHelper.fromDate(expiryDate);

  PantryItem copyWith({
    String? id,
    String? name,
    PantryCategory? category,
    PantryLocation? location,
    double? quantity,
    PantryUnit? unit,
    double? price,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? firestoreId,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? unitPrice,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // Always keep the Firestore document ID unless a new one is provided.
      firestoreId: firestoreId ?? this.firestoreId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'location': location.name,
      'quantity': quantity,
      'unit': unit.name,
      'price': unitPrice,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Firestore document fields for create and Used Up restore.
  ///
  /// Enums are stored as names. Dates use [Timestamp]. [createdAt] is kept
  /// when [preserveCreatedAt] is true so Undo recreates the same document.
  Map<String, dynamic> toFirestore({
    required String userId,
    bool preserveCreatedAt = false,
  }) {
    return {
      'name': name,
      'category': category.name,
      'location': location.name,
      'quantity': quantity,
      'unit': unit.name,
      'price': unitPrice,
      'expiryDate': expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
      'userId': userId,
      'createdAt': preserveCreatedAt && createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PantryItem.fromMap(String id, Map<String, dynamic> data) {
    final firestoreId = _stringField(data['firestoreId']);
    return PantryItem(
      id: id,
      firestoreId: firestoreId.isNotEmpty ? firestoreId : id,
      name: _stringField(data['name']),
      category: PantryCategory.fromStorage(_stringField(data['category'])),
      location: PantryLocation.fromStorage(_stringField(data['location'])),
      quantity: _numField(data['quantity']),
      unit: PantryUnit.fromStorage(_stringField(data['unit'])),
      price: _numField(data['price']),
      expiryDate: _parseDate(data['expiryDate']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  /// Converts a Firestore pantry document. [documentId] is stored as id and firestoreId.
  factory PantryItem.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return PantryItem.fromMap(documentId, data);
  }

  static String _stringField(dynamic value) {
    if (value is String) return value;
    return '';
  }

  static double _numField(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
