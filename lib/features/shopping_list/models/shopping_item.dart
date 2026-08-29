class ShoppingItem {
  final String name;
  final int quantity;
  final bool isPurchased;

  const ShoppingItem({
    required this.name,
    required this.quantity,
    this.isPurchased = false,
  });

  ShoppingItem copyWith({bool? isPurchased}) {
    return ShoppingItem(
      name: name,
      quantity: quantity,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }
}
