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
  bottles,
  boxes;

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
      case PantryUnit.boxes:
        return 'Boxes';
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
      case PantryUnit.boxes:
        return isSingular ? 'box' : 'boxes';
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

/// How [PantryItem.priceAmount] should be interpreted.
///
/// Firestore stores the enum name (`unitPrice` or `totalPrice`), never a
/// display label.
enum PantryPriceType {
  unitPrice,
  totalPrice;

  String get label {
    switch (this) {
      case PantryPriceType.unitPrice:
        return 'Unit Price';
      case PantryPriceType.totalPrice:
        return 'Total Price';
    }
  }

  String get explanation {
    switch (this) {
      case PantryPriceType.unitPrice:
        return 'Price for each item or measurement unit';
      case PantryPriceType.totalPrice:
        return 'Price paid for the full quantity entered';
    }
  }

  /// Suggestion only. The form may keep a choice the user made by hand.
  static PantryPriceType suggestedFor(PantryUnit unit) {
    switch (unit) {
      case PantryUnit.kg:
      case PantryUnit.g:
      case PantryUnit.liters:
      case PantryUnit.ml:
        return PantryPriceType.unitPrice;
      case PantryUnit.items:
      case PantryUnit.packs:
      case PantryUnit.bottles:
      case PantryUnit.boxes:
        return PantryPriceType.totalPrice;
    }
  }

  static PantryPriceType fromStorage(Object? value) {
    final normalized = value is String ? value.trim() : '';
    for (final type in PantryPriceType.values) {
      if (type.name == normalized) return type;
    }
    // Older documents have no price type. Treat their single price as the
    // amount paid for the whole quantity so waste estimates are not inflated
    // by multiplying that total by the remaining quantity.
    return PantryPriceType.totalPrice;
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
    double? originalQuantity,
    required this.unit,
    double? price,
    double? priceAmount,
    PantryPriceType? priceType,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
    this.firestoreId,
    this.photoUrl,
    this.photoStoragePath,
    this.imagePublicId,
    this.imageProvider,
  }) : originalQuantity = originalQuantity ?? quantity,
       priceAmount = priceAmount ?? price,
       priceType = priceType ?? PantryPriceType.totalPrice;

  final String id;
  final String name;
  final PantryCategory category;
  final PantryLocation location;

  /// Quantity still in the pantry. +/- controls and Used Up change this only.
  final double quantity;

  /// Quantity first purchased or entered. Kept so a later remaining quantity
  /// can be valued as a fraction of the amount paid. Not overwritten by +/-.
  final double originalQuantity;
  final PantryUnit unit;

  /// Numeric amount whose meaning comes from [priceType].
  ///
  /// `unitPrice` is the price of one reference unit (per kg, per L, or per
  /// item). `totalPrice` is the amount paid for [originalQuantity].
  /// Null when the user did not enter a price. The legacy constructor
  /// argument `price` fills this same field.
  final double? priceAmount;

  final PantryPriceType priceType;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Cloud Firestore document ID under users/{uid}/pantryItems/{itemId}.
  /// Null until the item has been written to Firestore.
  final String? firestoreId;

  /// Network photo URL. Cloudinary `secure_url` for new uploads, or a legacy
  /// Firebase Storage download URL. Never image bytes or a local file path.
  final String? photoUrl;

  /// Legacy Firebase Storage object path. New Cloudinary photos leave this null.
  final String? photoStoragePath;

  /// Cloudinary `public_id`. Null for items without a Cloudinary photo.
  final String? imagePublicId;

  /// `cloudinary` when [photoUrl] came from Cloudinary. Null for legacy photos.
  final String? imageProvider;

  /// True when this item can be updated or deleted in Cloud Firestore.
  bool get isConnectedToFirestore =>
      firestoreId != null && firestoreId!.trim().isNotEmpty;

  /// True when a user-uploaded photo should be shown instead of the
  /// category icon. Empty strings from older documents are treated as absent.
  bool get hasUserPhoto {
    final url = photoUrl;
    return url != null && url.trim().isNotEmpty;
  }

  /// Legacy accessor for [priceAmount]. Not necessarily a per-unit price;
  /// read [priceType] before using it in a formula.
  double? get price => priceAmount;

  /// Stored amount, or 0 when no price was entered.
  double get unitPrice {
    final amount = priceAmount;
    if (amount == null || !amount.isFinite || amount < 0) return 0;
    return amount;
  }

  /// True when a positive price was entered. Zero is treated as not provided
  /// so the UI does not present `Rs. 0.00` as a real purchase price.
  bool get hasPrice => unitPrice > 0;

  String get priceLabel => 'Rs. ${unitPrice.toStringAsFixed(2)}';

  /// Value of the food still in the pantry. Derived, never stored.
  double get estimatedRemainingValue => calculateRemainingValue(this);

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
      case PantryUnit.boxes:
        return 1;
    }
  }

  String get quantityLabel {
    final formatted = _formatQuantity(quantity);
    return '$formatted ${unit.displayLabel(quantity)}';
  }

  String get originalQuantityLabel {
    final formatted = _formatQuantity(originalQuantity);
    return '$formatted ${unit.displayLabel(originalQuantity)}';
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

  /// Changes the remaining [quantity] by [delta], never below zero.
  /// [originalQuantity], [priceType], and [priceAmount] stay as they are.
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
    double? originalQuantity,
    PantryUnit? unit,
    double? price,
    double? priceAmount,
    PantryPriceType? priceType,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? firestoreId,
    String? photoUrl,
    String? photoStoragePath,
    String? imagePublicId,
    String? imageProvider,
    bool clearPhoto = false,
    bool clearPhotoStoragePath = false,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      originalQuantity: originalQuantity ?? this.originalQuantity,
      unit: unit ?? this.unit,
      priceAmount: priceAmount ?? price ?? this.priceAmount,
      priceType: priceType ?? this.priceType,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // Always keep the Firestore document ID unless a new one is provided.
      firestoreId: firestoreId ?? this.firestoreId,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      photoStoragePath: clearPhoto
          ? null
          : clearPhotoStoragePath
          ? photoStoragePath
          : (photoStoragePath ?? this.photoStoragePath),
      imagePublicId: clearPhoto ? null : (imagePublicId ?? this.imagePublicId),
      imageProvider: clearPhoto ? null : (imageProvider ?? this.imageProvider),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'location': location.name,
      'quantity': quantity,
      'originalQuantity': originalQuantity,
      'unit': unit.name,
      'priceType': priceType.name,
      'priceAmount': priceAmount,
      // Kept equal to priceAmount so older readers still see a number.
      'price': priceAmount,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'photoUrl': photoUrl,
      'photoStoragePath': photoStoragePath,
      'imagePublicId': imagePublicId,
      'imageProvider': imageProvider,
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
    final data = <String, dynamic>{
      'name': name,
      'category': category.name,
      'location': location.name,
      'quantity': quantity,
      'originalQuantity': originalQuantity,
      'unit': unit.name,
      'priceType': priceType.name,
      'priceAmount': priceAmount,
      // Kept equal to priceAmount so older readers still see a number.
      'price': priceAmount,
      'expiryDate': expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
      'userId': userId,
      'createdAt': preserveCreatedAt && createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // URL only — Used Up Undo restores the same photo fields. Cloudinary
    // files are not deleted from this client.
    if (hasUserPhoto) {
      data['photoUrl'] = photoUrl;
      if (photoStoragePath != null) {
        data['photoStoragePath'] = photoStoragePath;
      }
      if (imagePublicId != null) data['imagePublicId'] = imagePublicId;
      if (imageProvider != null) data['imageProvider'] = imageProvider;
    }
    return data;
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
      originalQuantity: data.containsKey('originalQuantity')
          ? _numField(data['originalQuantity'])
          : _numField(data['quantity']),
      unit: PantryUnit.fromStorage(_stringField(data['unit'])),
      priceAmount: _readPriceAmount(data),
      priceType: PantryPriceType.fromStorage(data['priceType']),
      expiryDate: _parseDate(data['expiryDate']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      photoUrl:
          _optionalString(data['photoUrl']) ??
          _optionalString(data['imageUrl']),
      photoStoragePath: _optionalString(data['photoStoragePath']),
      imagePublicId: _optionalString(data['imagePublicId']),
      imageProvider: _optionalString(data['imageProvider']),
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

  static String? _optionalString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double _numField(dynamic value) {
    final parsed = _optionalNum(value);
    if (parsed == null || !parsed.isFinite || parsed < 0) return 0;
    return parsed;
  }

  static double? _optionalNum(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Prefers [priceAmount]. Falls back to the legacy `price` field, which is
  /// read as a total price by [PantryPriceType.fromStorage].
  static double? _readPriceAmount(Map<String, dynamic> data) {
    if (data.containsKey('priceAmount')) {
      return _finitePrice(data['priceAmount']);
    }
    if (data.containsKey('price')) {
      return _finitePrice(data['price']);
    }
    return null;
  }

  static double? _finitePrice(dynamic value) {
    final parsed = _optionalNum(value);
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed;
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

/// Remaining value of [item] from its quantity, unit, and price.
///
/// Not written to Firestore. A saved total would become stale as soon as the
/// remaining quantity changes.
///
/// Future Expiry and Waste Tracker flow: when a pantry item expires, read the
/// remaining quantity, call this function, and store that number as a snapshot
/// on the waste record.
double calculateRemainingValue(PantryItem item) {
  final amount = item.priceAmount;
  if (amount == null || !amount.isFinite || amount <= 0) return 0;

  final remaining = item.quantity;
  if (!remaining.isFinite || remaining <= 0) return 0;

  final raw = switch (item.priceType) {
    PantryPriceType.unitPrice => _valueAtUnitPrice(
      item.unit,
      remaining,
      amount,
    ),
    PantryPriceType.totalPrice => _valueAtTotalPrice(
      remaining,
      item.originalQuantity,
      amount,
    ),
  };
  if (!raw.isFinite || raw < 0) return 0;
  return raw;
}

double _valueAtUnitPrice(PantryUnit unit, double quantity, double price) {
  // Grams and millilitres stay in the stored unit. The price the user entered
  // is per kilogram or per litre, so convert before multiplying.
  final referenceQuantity = switch (unit) {
    PantryUnit.g || PantryUnit.ml => quantity / 1000,
    _ => quantity,
  };
  return referenceQuantity * price;
}

double _valueAtTotalPrice(double remaining, double original, double total) {
  if (!original.isFinite || original <= 0) return 0;
  return (remaining / original) * total;
}
