import 'package:firebase_core/firebase_core.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';

// Technical details belong in debug logs, not in end-user messages.
String shoppingErrorMessage(Object error) {
  if (error is ShoppingQuantityLimitException) {
    return 'Maximum quantity is 100.';
  }
  if (error is ShoppingListDeleteException) {
    return '${error.deletedItemIds.length} items were deleted, but the remaining '
        'items could not be deleted. Refresh your list before trying again.';
  }
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return "You don't have permission to access this shopping list. Please contact the team.";
    }
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return 'Unable to reach your shopping list. Check your connection and try again.';
    }
    if (error.code == 'not-found') {
      return 'This item no longer exists. Refresh your list and try again.';
    }
  }
  if (error is StateError) {
    return 'Your shopping list or account changed. Please reopen it and try again.';
  }
  if (error is ArgumentError) {
    return 'Enter an item name and a quantity from 1 to 100.';
  }
  if (error is FormatException) {
    return 'A saved item could not be loaded. Please contact the team.';
  }
  return 'Unable to complete this shopping action. Please try again.';
}
