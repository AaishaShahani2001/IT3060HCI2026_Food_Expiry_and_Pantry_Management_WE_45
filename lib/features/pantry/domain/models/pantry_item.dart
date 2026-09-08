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
    return PantryLocation.values.firstWhere(
      (location) => location.name == value,
      orElse: () => PantryLocation.pantry,
    );
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
    return PantryCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => PantryCategory.other,
    );
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
    return PantryUnit.values.firstWhere(
      (unit) => unit.name == value,
      orElse: () => PantryUnit.items,
    );
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
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final PantryCategory category;
  final PantryLocation location;
  final double quantity;
  final PantryUnit unit;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'location': location.name,
      'quantity': quantity,
      'unit': unit.name,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory PantryItem.fromMap(String id, Map<String, dynamic> data) {
    return PantryItem(
      id: id,
      name: data['name'] as String? ?? '',
      category: PantryCategory.fromStorage(data['category'] as String? ?? ''),
      location: PantryLocation.fromStorage(data['location'] as String? ?? ''),
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      unit: PantryUnit.fromStorage(data['unit'] as String? ?? ''),
      expiryDate: _parseDate(data['expiryDate']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
