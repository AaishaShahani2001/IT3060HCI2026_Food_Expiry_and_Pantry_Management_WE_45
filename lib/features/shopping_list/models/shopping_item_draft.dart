import '../../pantry/domain/models/pantry_item.dart';
import '../data/shopping_item_metadata.dart';

/// Immutable values used to open the existing Shopping List form.
///
/// Quantity stays null unless the caller already has a purchase quantity the
/// user still has to confirm. Used Up does not copy the consumed pantry
/// quantity into this draft.
class ShoppingItemDraft {
  const ShoppingItemDraft({this.name, this.category, this.unit, this.quantity});

  final String? name;
  final String? category;
  final PantryUnit? unit;

  /// Purchase quantity. Null leaves the form blank so the user must enter one.
  final int? quantity;

  /// Maps a pantry snapshot onto the Shopping List form's category and unit.
  ///
  /// Category goes through [shoppingCategoryForPantryItem] so the form reuses
  /// the existing shopping categories. Quantity is intentionally omitted.
  factory ShoppingItemDraft.fromPantryItem(PantryItem item) {
    final name = item.name.trim();
    return ShoppingItemDraft(
      name: name.isEmpty ? null : name,
      category: shoppingCategoryForPantryItem(item),
      unit: item.unit,
    );
  }

  /// Reads a prefill from the add-item route query.
  ///
  /// Returns null when the query has no shopping fields, so a normal empty
  /// form is unchanged.
  static ShoppingItemDraft? fromQuery(Map<String, String> params) {
    final name = params['name']?.trim();
    final category = params['category']?.trim();
    final unitName = params['unit']?.trim();
    final quantity = int.tryParse(params['quantity']?.trim() ?? '');
    final hasName = name != null && name.isNotEmpty;
    final hasCategory = category != null && category.isNotEmpty;
    final hasUnit = unitName != null && unitName.isNotEmpty;
    if (!hasName && !hasCategory && !hasUnit && quantity == null) return null;
    return ShoppingItemDraft(
      name: hasName ? name : null,
      category: hasCategory ? category : null,
      unit: hasUnit ? PantryUnit.fromStorage(unitName) : null,
      quantity: quantity,
    );
  }
}
