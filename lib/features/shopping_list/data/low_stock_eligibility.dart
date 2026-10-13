import '../../pantry/domain/models/pantry_item.dart';
import '../../pantry/domain/utils/expiry_status.dart';

/// Uses Pantry's existing date semantics without coupling Shopping to Expiry UI.
bool hasEligibleShoppingLowStockExpiry(PantryItem item) =>
    item.expiryStatus != ExpiryStatus.expired;
