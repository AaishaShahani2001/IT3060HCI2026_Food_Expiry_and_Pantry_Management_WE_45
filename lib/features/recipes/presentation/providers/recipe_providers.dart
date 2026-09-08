import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_recipe_repository.dart';
import '../../domain/models/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return MockRecipeRepository();
});

class RecipeFilterState {
  const RecipeFilterState({
    this.searchQuery = '',
    this.category,
    this.favoritesOnly = false,
  });

  final String searchQuery;
  final RecipeCategory? category;
  final bool favoritesOnly;

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty || category != null || favoritesOnly;

  RecipeFilterState copyWith({
    String? searchQuery,
    RecipeCategory? category,
    bool? favoritesOnly,
    bool clearCategory = false,
  }) {
    return RecipeFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      category: clearCategory ? null : (category ?? this.category),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

class RecipeFilterNotifier extends Notifier<RecipeFilterState> {
  @override
  RecipeFilterState build() => const RecipeFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(RecipeCategory? category) {
    state = state.copyWith(category: category, clearCategory: category == null);
  }

  void setFavoritesOnly(bool value) {
    state = state.copyWith(favoritesOnly: value);
  }

  void clearFilters() {
    state = const RecipeFilterState();
  }
}

final recipeFilterProvider =
    NotifierProvider<RecipeFilterNotifier, RecipeFilterState>(
      RecipeFilterNotifier.new,
    );

class RecipesNotifier extends AsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() async {
    return ref.read(recipeRepositoryProvider).fetchRecipes();
  }

  Future<void> refreshRecipes() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => ref.read(recipeRepositoryProvider).fetchRecipes(),
    );
  }

  Future<void> addRecipe(Recipe recipe) async {
    final repository = ref.read(recipeRepositoryProvider);

    final createdRecipe = await repository.addRecipe(recipe);

    final currentRecipes = state.asData?.value ?? [];

    state = AsyncData([createdRecipe, ...currentRecipes]);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final repository = ref.read(recipeRepositoryProvider);

    final updatedRecipe = await repository.updateRecipe(recipe);

    final currentRecipes = state.asData?.value ?? [];

    state = AsyncData(
      currentRecipes
          .map((entry) => entry.id == updatedRecipe.id ? updatedRecipe : entry)
          .toList(),
    );
  }

  Future<void> deleteRecipe(String id) async {
    final repository = ref.read(recipeRepositoryProvider);

    await repository.deleteRecipe(id);

    final currentRecipes = state.asData?.value ?? [];

    state = AsyncData(
      currentRecipes.where((recipe) => recipe.id != id).toList(),
    );
  }

  Future<void> toggleFavorite(String id) async {
    final currentRecipes = state.asData?.value;

    if (currentRecipes == null) return;

    final index = currentRecipes.indexWhere((recipe) => recipe.id == id);

    if (index == -1) return;

    final currentRecipe = currentRecipes[index];

    final updatedRecipe = currentRecipe.copyWith(
      isFavorite: !currentRecipe.isFavorite,
    );

    final optimisticRecipes = [...currentRecipes];
    optimisticRecipes[index] = updatedRecipe;

    state = AsyncData(optimisticRecipes);

    try {
      final savedRecipe = await ref
          .read(recipeRepositoryProvider)
          .updateRecipe(updatedRecipe);

      final latestRecipes = state.asData?.value ?? optimisticRecipes;

      state = AsyncData(
        latestRecipes
            .map((recipe) => recipe.id == savedRecipe.id ? savedRecipe : recipe)
            .toList(),
      );
    } catch (_) {
      state = AsyncData(currentRecipes);
      rethrow;
    }
  }
}

final recipesProvider = AsyncNotifierProvider<RecipesNotifier, List<Recipe>>(
  RecipesNotifier.new,
);

final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipesAsync = ref.watch(recipesProvider);
  final filters = ref.watch(recipeFilterProvider);

  return recipesAsync.maybeWhen(
    data: (recipes) => _applyFilters(recipes, filters),
    orElse: () => const [],
  );
});

final recipeSummaryProvider = Provider<({int total, int favorites})>((ref) {
  final recipesAsync = ref.watch(recipesProvider);

  return recipesAsync.maybeWhen(
    data: (recipes) {
      final favorites = recipes.where((recipe) => recipe.isFavorite).length;

      return (total: recipes.length, favorites: favorites);
    },
    orElse: () => (total: 0, favorites: 0),
  );
});

List<Recipe> _applyFilters(List<Recipe> recipes, RecipeFilterState filters) {
  return recipes.where((recipe) {
    final matchesSearch =
        filters.searchQuery.isEmpty ||
        recipe.name.toLowerCase().contains(filters.searchQuery.toLowerCase());

    final matchesCategory =
        filters.category == null || recipe.category == filters.category;

    final matchesFavorites = !filters.favoritesOnly || recipe.isFavorite;

    return matchesSearch && matchesCategory && matchesFavorites;
  }).toList();
}
