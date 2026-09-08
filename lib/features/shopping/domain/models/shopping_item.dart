enum ShoppingItemPriority {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case ShoppingItemPriority.low:
        return 'Low';
      case ShoppingItemPriority.medium:
        return 'Medium';
      case ShoppingItemPriority.high:
        return 'High';
    }
  }

  static ShoppingItemPriority fromStorage(String value) {
    return ShoppingItemPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => ShoppingItemPriority.medium,
    );
  }
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.unit = 'items',
    this.priority = ShoppingItemPriority.medium,
    this.isCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final ShoppingItemPriority priority;
  final bool isCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get quantityLabel {
    final formattedQuantity = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);

    return '$formattedQuantity $unit';
  }

  ShoppingItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    ShoppingItemPriority? priority,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'priority': priority.name,
      'isCompleted': isCompleted,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ShoppingItem.fromMap(String id, Map<String, dynamic> data) {
    return ShoppingItem(
      id: id,
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1,
      unit: data['unit'] as String? ?? 'items',
      priority: ShoppingItemPriority.fromStorage(
        data['priority'] as String? ?? '',
      ),
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
