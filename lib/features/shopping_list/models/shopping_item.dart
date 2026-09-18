class ShoppingItem {
  final String? id;
  final String name;
  final int quantity;
  final bool isPurchased;
  final String? source;
  final String? sourcePantryItemId;

  const ShoppingItem({
    this.id,
    required this.name,
    required this.quantity,
    this.isPurchased = false,
    this.source,
    this.sourcePantryItemId,
  });

  ShoppingItem copyWith({
    String? id,
    String? name,
    int? quantity,
    bool? isPurchased,
    String? source,
    String? sourcePantryItemId,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      isPurchased: isPurchased ?? this.isPurchased,
      source: source ?? this.source,
      sourcePantryItemId: sourcePantryItemId ?? this.sourcePantryItemId,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'isPurchased': isPurchased,
    if (source != null) 'source': source,
    if (sourcePantryItemId != null) 'sourcePantryItemId': sourcePantryItemId,
  };

  factory ShoppingItem.fromMap(String id, Map<String, dynamic> data) {
    final name = data['name'];
    final quantity = data['quantity'];
    final isPurchased = data['isPurchased'] ?? false;
    if (id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        quantity is! int ||
        quantity < 1 ||
        quantity > 100 ||
        isPurchased is! bool) {
      throw FormatException('Invalid shopping item document: $id');
    }
    return ShoppingItem(
      id: id,
      name: name,
      quantity: quantity,
      isPurchased: isPurchased,
      source: data['source'] is String ? data['source'] as String : null,
      sourcePantryItemId: data['sourcePantryItemId'] is String
          ? data['sourcePantryItemId'] as String
          : null,
    );
  }
}
