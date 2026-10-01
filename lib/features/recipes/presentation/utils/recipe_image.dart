import '../../domain/models/recipe.dart';

/// Stock photo already chosen by the Recipes screen for a recipe name.
///
/// The recipe model has no image field. This is the existing name lookup.
String recipeDisplayImageUrl(Recipe recipe) {
  final name = recipe.name.toLowerCase();

  if (name.contains('fried rice')) {
    return 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=1000&q=85';
  }

  if (name.contains('pasta')) {
    return 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1000&q=85';
  }

  if (name.contains('salad')) {
    return 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1000&q=85';
  }

  if (name.contains('chicken')) {
    return 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=1000&q=85';
  }

  if (name.contains('soup')) {
    return 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1000&q=85';
  }

  if (name.contains('sandwich')) {
    return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=1000&q=85';
  }

  return 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=1000&q=85';
}
