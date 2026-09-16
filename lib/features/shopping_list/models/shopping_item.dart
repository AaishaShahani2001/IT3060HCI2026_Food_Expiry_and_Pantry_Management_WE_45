class ShoppingItem {
  final String? id;
  final String name;
  final int quantity;
  final bool isPurchased;

  const ShoppingItem({
    this.id,
    required this.name,
    required this.quantity,
    this.isPurchased = false,
  });

  ShoppingItem copyWith({
    String? id,
    String? name,
    int? quantity,
    bool? isPurchased,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'isPurchased': isPurchased,
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
    );
  }
}
