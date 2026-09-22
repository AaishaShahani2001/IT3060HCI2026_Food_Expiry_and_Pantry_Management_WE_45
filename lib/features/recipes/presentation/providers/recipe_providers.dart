import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_recipe_repository.dart';
import '../../domain/models/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';

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

/// Contains a recipe together with information about why it was recommended.
class RecipeRecommendation {
  const RecipeRecommendation({
    required this.recipe,
    required this.matchedIngredients,
    required this.score,
    this.expiringIngredient,
    this.daysUntilExpiry,
  });

  final Recipe recipe;

  /// Pantry items that match ingredients in this recipe.
  final List<String> matchedIngredients;

  /// Higher score = higher recommendation priority.
  final int score;

  /// The matched pantry item with the nearest expiry date.
  final String? expiringIngredient;

  /// Number of days remaining until the nearest expiry.
  final int? daysUntilExpiry;

  bool get hasExpiringIngredient =>
      expiringIngredient != null && daysUntilExpiry != null;
}

class RecipeFilterNotifier extends Notifier<RecipeFilterState> {
  @override
  RecipeFilterState build() => const RecipeFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(RecipeCategory? category) {
    state = state.copyWith(
      category: category,
      clearCategory: category == null,
    );
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

    state = AsyncData([
      createdRecipe,
      ...currentRecipes,
    ]);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final repository = ref.read(recipeRepositoryProvider);

    final updatedRecipe = await repository.updateRecipe(recipe);

    final currentRecipes = state.asData?.value ?? [];

    state = AsyncData(
      currentRecipes
          .map(
            (entry) =>
        entry.id == updatedRecipe.id ? updatedRecipe : entry,
      )
          .toList(),
    );
  }

  Future<void> deleteRecipe(String id) async {
    final repository = ref.read(recipeRepositoryProvider);

    await repository.deleteRecipe(id);

    final currentRecipes = state.asData?.value ?? [];

    state = AsyncData(
      currentRecipes
          .where((recipe) => recipe.id != id)
          .toList(),
    );
  }

  Future<void> toggleFavorite(String id) async {
    final currentRecipes = state.asData?.value;

    if (currentRecipes == null) return;

    final index = currentRecipes.indexWhere(
          (recipe) => recipe.id == id,
    );

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

      final latestRecipes =
          state.asData?.value ?? optimisticRecipes;

      state = AsyncData(
        latestRecipes
            .map(
              (recipe) => recipe.id == savedRecipe.id
              ? savedRecipe
              : recipe,
        )
            .toList(),
      );
    } catch (_) {
      state = AsyncData(currentRecipes);
      rethrow;
    }
  }
}

final recipesProvider =
AsyncNotifierProvider<RecipesNotifier, List<Recipe>>(
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

final recipeSummaryProvider =
Provider<({int total, int favorites})>((ref) {
  final recipesAsync = ref.watch(recipesProvider);

  return recipesAsync.maybeWhen(
    data: (recipes) {
      final favorites =
          recipes.where((recipe) => recipe.isFavorite).length;

      return (
      total: recipes.length,
      favorites: favorites,
      );
    },
    orElse: () => (
    total: 0,
    favorites: 0,
    ),
  );
});

List<Recipe> _applyFilters(
    List<Recipe> recipes,
    RecipeFilterState filters,
    ) {
  return recipes.where((recipe) {
    final matchesSearch =
        filters.searchQuery.isEmpty ||
            recipe.name
                .toLowerCase()
                .contains(filters.searchQuery.toLowerCase());

    final matchesCategory =
        filters.category == null ||
            recipe.category == filters.category;

    final matchesFavorites =
        !filters.favoritesOnly || recipe.isFavorite;

    return matchesSearch &&
        matchesCategory &&
        matchesFavorites;
  }).toList();
}

/// Provides recipes recommended from the user's available pantry items.
///
/// Recommendation is rule-based:
///
/// - Available matching ingredient: +3 points
/// - Matching ingredient expiring within 3 days: +5 points
/// - Matching ingredient expiring within 7 days: +3 points
///
/// Recipes are sorted from highest score to lowest score.
final recommendedRecipesProvider =
Provider<List<RecipeRecommendation>>((ref) {
  final pantryItemsAsync = ref.watch(pantryItemsProvider);
  final recipesAsync = ref.watch(recipesProvider);

  final pantryItems = pantryItemsAsync.maybeWhen(
    data: (items) => items,
    orElse: () => const [],
  );

  final recipes = recipesAsync.maybeWhen(
    data: (items) => items,
    orElse: () => const [],
  );

  if (pantryItems.isEmpty || recipes.isEmpty) {
    return const [];
  }

  final recommendations = <RecipeRecommendation>[];

  for (final recipe in recipes) {
    final matchedIngredients = <String>[];

    String? expiringIngredient;
    int? daysUntilExpiry;

    int score = 0;

    for (final pantryItem in pantryItems) {
      // Do not recommend recipes based on food that has no quantity left.
      if (pantryItem.quantity <= 0) {
        continue;
      }

      final pantryName = pantryItem.name.trim().toLowerCase();

      if (pantryName.isEmpty) {
        continue;
      }

      // Match pantry item name against recipe ingredients.
      final ingredientMatches = recipe.ingredients.any(
            (ingredient) {
          final recipeIngredient =
          ingredient.trim().toLowerCase();

          if (recipeIngredient.isEmpty) {
            return false;
          }

          return recipeIngredient.contains(pantryName) ||
              pantryName.contains(recipeIngredient);
        },
      );

      if (!ingredientMatches) {
        continue;
      }

      // Available ingredient match.
      score += 3;

      if (!matchedIngredients.contains(pantryItem.name)) {
        matchedIngredients.add(pantryItem.name);
      }

      final expiryDate = pantryItem.expiryDate;

      if (expiryDate == null) {
        continue;
      }

      final now = DateTime.now();

      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final expiryDay = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );

      final days = expiryDay.difference(today).inDays;

      // Highest priority:
      // ingredient expires within 3 days.
      if (days >= 0 && days <= 3) {
        score += 5;

        if (daysUntilExpiry == null ||
            days < daysUntilExpiry) {
          expiringIngredient = pantryItem.name;
          daysUntilExpiry = days;
        }
      }

      // Medium priority:
      // ingredient expires within 7 days.
      else if (days > 3 && days <= 7) {
        score += 3;

        if (daysUntilExpiry == null ||
            days < daysUntilExpiry) {
          expiringIngredient = pantryItem.name;
          daysUntilExpiry = days;
        }
      }
    }

    // Only recommend recipes that use at least
    // one currently available pantry ingredient.
    if (matchedIngredients.isNotEmpty) {
      recommendations.add(
        RecipeRecommendation(
          recipe: recipe,
          matchedIngredients: matchedIngredients,
          score: score,
          expiringIngredient: expiringIngredient,
          daysUntilExpiry: daysUntilExpiry,
        ),
      );
    }
  }

  // Highest recommendation score first.
  recommendations.sort(
        (a, b) => b.score.compareTo(a.score),
  );

  return recommendations;
});