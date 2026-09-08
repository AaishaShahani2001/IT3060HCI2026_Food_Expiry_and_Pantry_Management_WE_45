import '../models/recipe.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> fetchRecipes();

  Future<Recipe> addRecipe(Recipe recipe);

  Future<Recipe> updateRecipe(Recipe recipe);

  Future<void> deleteRecipe(String id);
}
