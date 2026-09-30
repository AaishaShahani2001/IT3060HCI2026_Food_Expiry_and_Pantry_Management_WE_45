import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_recipe_repository.dart';
import '../../domain/models/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return MockRecipeRepository();
});

// ================================================================
// USER DIETARY PROFILE
// ================================================================

class UserDietaryProfile {
  const UserDietaryProfile({
    this.preferences = const [],
    this.allergies = const [],
  });

  final List<String> preferences;
  final List<String> allergies;
}

final userDietaryProfileProvider =
FutureProvider<UserDietaryProfile>((ref) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return const UserDietaryProfile();
  }

  final document = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  final data = document.data();

  if (data == null) {
    return const UserDietaryProfile();
  }

  List<String> convertToList(dynamic value) {
    if (value is List) {
      return value
          .map(
            (item) => item.toString().trim().toLowerCase(),
      )
          .where(
            (item) => item.isNotEmpty,
      )
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map(
            (item) => item.trim().toLowerCase(),
      )
          .where(
            (item) => item.isNotEmpty,
      )
          .toList();
    }

    return const [];
  }

  return UserDietaryProfile(
    preferences: convertToList(
      data['foodPreferences'],
    ),
    allergies: convertToList(
      data['allergies'],
    ),
  );
});

// ================================================================
// RECIPE FILTER STATE
// ================================================================

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
      searchQuery.isNotEmpty ||
          category != null ||
          favoritesOnly;

  RecipeFilterState copyWith({
    String? searchQuery,
    RecipeCategory? category,
    bool? favoritesOnly,
    bool clearCategory = false,
  }) {
    return RecipeFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      category: clearCategory
          ? null
          : (category ?? this.category),
      favoritesOnly:
      favoritesOnly ?? this.favoritesOnly,
    );
  }
}

class RecipeFilterNotifier
    extends Notifier<RecipeFilterState> {
  @override
  RecipeFilterState build() {
    return const RecipeFilterState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
    );
  }

  void setCategory(RecipeCategory? category) {
    state = state.copyWith(
      category: category,
      clearCategory: category == null,
    );
  }

  void setFavoritesOnly(bool value) {
    state = state.copyWith(
      favoritesOnly: value,
    );
  }

  void clearFilters() {
    state = const RecipeFilterState();
  }
}

final recipeFilterProvider =
NotifierProvider<
    RecipeFilterNotifier,
    RecipeFilterState>(
  RecipeFilterNotifier.new,
);

// ================================================================
// RECIPES NOTIFIER
// ================================================================

class RecipesNotifier
    extends AsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() async {
    return ref
        .read(recipeRepositoryProvider)
        .fetchRecipes();
  }

  Future<void> refreshRecipes() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
          () => ref
          .read(recipeRepositoryProvider)
          .fetchRecipes(),
    );
  }

  Future<void> addRecipe(
      Recipe recipe,
      ) async {
    final repository =
    ref.read(recipeRepositoryProvider);

    final createdRecipe =
    await repository.addRecipe(recipe);

    final currentRecipes =
        state.asData?.value ?? [];

    state = AsyncData([
      createdRecipe,
      ...currentRecipes,
    ]);
  }

  Future<void> updateRecipe(
      Recipe recipe,
      ) async {
    final repository =
    ref.read(recipeRepositoryProvider);

    final updatedRecipe =
    await repository.updateRecipe(recipe);

    final currentRecipes =
        state.asData?.value ?? [];

    state = AsyncData(
      currentRecipes
          .map(
            (entry) => entry.id == updatedRecipe.id
            ? updatedRecipe
            : entry,
      )
          .toList(),
    );
  }

  Future<void> deleteRecipe(
      String id,
      ) async {
    final repository =
    ref.read(recipeRepositoryProvider);

    await repository.deleteRecipe(id);

    final currentRecipes =
        state.asData?.value ?? [];

    state = AsyncData(
      currentRecipes
          .where(
            (recipe) => recipe.id != id,
      )
          .toList(),
    );
  }

  Future<void> toggleFavorite(
      String id,
      ) async {
    final currentRecipes =
        state.asData?.value;

    if (currentRecipes == null) {
      return;
    }

    final index = currentRecipes.indexWhere(
          (recipe) => recipe.id == id,
    );

    if (index == -1) {
      return;
    }

    final currentRecipe =
    currentRecipes[index];

    final updatedRecipe =
    currentRecipe.copyWith(
      isFavorite:
      !currentRecipe.isFavorite,
    );

    final optimisticRecipes =
    [...currentRecipes];

    optimisticRecipes[index] =
        updatedRecipe;

    state = AsyncData(
      optimisticRecipes,
    );

    try {
      final savedRecipe = await ref
          .read(recipeRepositoryProvider)
          .updateRecipe(updatedRecipe);

      final latestRecipes =
          state.asData?.value ??
              optimisticRecipes;

      state = AsyncData(
        latestRecipes
            .map(
              (recipe) => recipe.id ==
              savedRecipe.id
              ? savedRecipe
              : recipe,
        )
            .toList(),
      );
    } catch (_) {
      state = AsyncData(
        currentRecipes,
      );

      rethrow;
    }
  }
}

final recipesProvider =
AsyncNotifierProvider<
    RecipesNotifier,
    List<Recipe>>(
  RecipesNotifier.new,
);

// ================================================================
// FILTERED RECIPES
// ================================================================

final filteredRecipesProvider =
Provider<List<Recipe>>((ref) {
  final recipesAsync =
  ref.watch(recipesProvider);

  final filters =
  ref.watch(recipeFilterProvider);

  return recipesAsync.maybeWhen(
    data: (recipes) =>
        _applyFilters(recipes, filters),
    orElse: () => const [],
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
                .contains(
              filters.searchQuery
                  .toLowerCase(),
            );

    final matchesCategory =
        filters.category == null ||
            recipe.category ==
                filters.category;

    final matchesFavorites =
        !filters.favoritesOnly ||
            recipe.isFavorite;

    return matchesSearch &&
        matchesCategory &&
        matchesFavorites;
  }).toList();
}

// ================================================================
// RECIPE SUMMARY
// ================================================================

final recipeSummaryProvider =
Provider<({int total, int favorites})>(
      (ref) {
    final recipesAsync =
    ref.watch(recipesProvider);

    return recipesAsync.maybeWhen(
      data: (recipes) {
        final favorites = recipes
            .where(
              (recipe) =>
          recipe.isFavorite,
        )
            .length;

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
  },
);

// ================================================================
// ALLERGY MATCHING
// ================================================================

bool _recipeContainsAllergy(
    Recipe recipe,
    String allergy,
    ) {
  final allergyKeywords =
  <String, List<String>>{
    'peanuts': [
      'peanut',
      'peanuts',
    ],
    'milk / dairy': [
      'milk',
      'yogurt',
      'yoghurt',
      'cheese',
      'butter',
      'cream',
      'dairy',
    ],
    'eggs': [
      'egg',
      'eggs',
    ],
    'seafood': [
      'seafood',
      'fish',
      'prawn',
      'prawns',
      'shrimp',
      'crab',
      'tuna',
      'salmon',
    ],
    'soy': [
      'soy',
      'soya',
      'soy sauce',
      'tofu',
      'edamame',
    ],
    'gluten': [
      'wheat',
      'bread',
      'pasta',
      'flour',
      'noodles',
      'gluten',
    ],
  };

  final keywords =
      allergyKeywords[allergy] ??
          [allergy];

  return recipe.ingredients.any(
        (ingredient) {
      final ingredientName =
      ingredient.toLowerCase();

      return keywords.any(
            (keyword) =>
            ingredientName.contains(
              keyword,
            ),
      );
    },
  );
}

// ================================================================
// DIETARY PREFERENCE MATCHING
// ================================================================

int _preferenceScore(
    Recipe recipe,
    List<String> preferences,
    ) {
  var score = 0;

  for (final preference
  in preferences) {
    final matchesTag = recipe.tags.any(
          (tag) =>
      tag.toLowerCase() ==
          preference,
    );

    if (matchesTag) {
      score += 6;
    }
  }

  return score;
}

// ================================================================
// VEGETARIAN / VEGAN SAFETY
// ================================================================

bool _isVegetarianSafe(
    Recipe recipe,
    ) {
  const meatKeywords = [
    'chicken',
    'beef',
    'pork',
    'mutton',
    'lamb',
    'meat',
    'ham',
    'bacon',
    'sausage',
    'turkey',
    'duck',
    'fish',
    'prawn',
    'prawns',
    'shrimp',
    'crab',
    'tuna',
    'salmon',
    'seafood',
  ];

  return !recipe.ingredients.any(
        (ingredient) {
      final value =
      ingredient.toLowerCase();

      return meatKeywords.any(
            (keyword) =>
            value.contains(keyword),
      );
    },
  );
}

bool _isVeganSafe(
    Recipe recipe,
    ) {
  const animalProductKeywords = [
    'chicken',
    'beef',
    'pork',
    'mutton',
    'lamb',
    'meat',
    'fish',
    'prawn',
    'prawns',
    'shrimp',
    'crab',
    'tuna',
    'salmon',
    'seafood',
    'egg',
    'eggs',
    'milk',
    'yogurt',
    'yoghurt',
    'cheese',
    'butter',
    'cream',
    'honey',
    'dairy',
  ];

  return !recipe.ingredients.any(
        (ingredient) {
      final value =
      ingredient.toLowerCase();

      return animalProductKeywords.any(
            (keyword) =>
            value.contains(keyword),
      );
    },
  );
}

bool _violatesDietaryPreference(
    Recipe recipe,
    List<String> preferences,
    ) {
  if (preferences.contains(
    'vegetarian',
  )) {
    if (!_isVegetarianSafe(recipe)) {
      return true;
    }
  }

  if (preferences.contains(
    'vegan',
  )) {
    if (!_isVeganSafe(recipe)) {
      return true;
    }
  }

  return false;
}

// ================================================================
// RECOMMENDED RECIPES
// ================================================================

/// Provides recipes recommended using:
///
/// - User food allergies
/// - User dietary preferences
/// - Available pantry ingredients
/// - Pantry expiry dates
///
/// Scoring:
///
/// Allergy conflict:
///   Recipe is excluded.
///
/// Vegetarian / Vegan conflict:
///   Recipe is excluded.
///
/// Preference match:
///   +6 points
///
/// Available matching ingredient:
///   +3 points
///
/// Matching ingredient expiring within 3 days:
///   +5 points
///
/// Matching ingredient expiring within 7 days:
///   +3 points
///
/// Only recipes using at least one available
/// pantry ingredient are recommended.
final recommendedRecipesProvider =
Provider<List<RecipeRecommendation>>(
      (ref) {
    final pantryItemsAsync =
    ref.watch(pantryItemsProvider);

    final recipesAsync =
    ref.watch(recipesProvider);

    final profileAsync =
    ref.watch(
      userDietaryProfileProvider,
    );

    final pantryItems =
    pantryItemsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const [],
    );

    final recipes =
    recipesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const [],
    );

    final profile =
    profileAsync.maybeWhen(
      data: (value) => value,
      orElse: () =>
      const UserDietaryProfile(),
    );

    if (pantryItems.isEmpty ||
        recipes.isEmpty) {
      return const [];
    }

    final recommendations =
    <RecipeRecommendation>[];

    for (final recipe in recipes) {
      // ==========================================================
      // 1. ALLERGY SAFETY FILTER
      // ==========================================================

      final hasAllergyConflict =
      profile.allergies.any(
            (allergy) =>
            _recipeContainsAllergy(
              recipe,
              allergy,
            ),
      );

      if (hasAllergyConflict) {
        continue;
      }

      // ==========================================================
      // 2. DIETARY PREFERENCE SAFETY
      // ==========================================================

      final violatesDiet =
      _violatesDietaryPreference(
        recipe,
        profile.preferences,
      );

      if (violatesDiet) {
        continue;
      }

      // ==========================================================
      // 3. INITIAL PREFERENCE SCORE
      // ==========================================================

      var score = _preferenceScore(
        recipe,
        profile.preferences,
      );

      final matchedIngredients =
      <String>[];

      String? expiringIngredient;
      int? daysUntilExpiry;

      // ==========================================================
      // 4. PANTRY + EXPIRY MATCHING
      // ==========================================================

      for (final pantryItem
      in pantryItems) {
        // Do not recommend recipes based
        // on food that has no quantity left.
        if (pantryItem.quantity <= 0) {
          continue;
        }

        final pantryName =
        pantryItem.name
            .trim()
            .toLowerCase();

        if (pantryName.isEmpty) {
          continue;
        }

        // Match pantry item name against
        // recipe ingredients.
        final ingredientMatches =
        recipe.ingredients.any(
              (ingredient) {
            final recipeIngredient =
            ingredient
                .trim()
                .toLowerCase();

            if (recipeIngredient.isEmpty) {
              return false;
            }

            return recipeIngredient
                .contains(pantryName) ||
                pantryName.contains(
                  recipeIngredient,
                );
          },
        );

        if (!ingredientMatches) {
          continue;
        }

        // --------------------------------------------------------
        // Available ingredient match
        // --------------------------------------------------------

        score += 3;

        if (!matchedIngredients
            .contains(pantryItem.name)) {
          matchedIngredients.add(
            pantryItem.name,
          );
        }

        // --------------------------------------------------------
        // Expiry priority
        // --------------------------------------------------------

        final expiryDate =
            pantryItem.expiryDate;

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

        final days = expiryDay
            .difference(today)
            .inDays;

        // Highest priority:
        // ingredient expires within 3 days.
        if (days >= 0 && days <= 3) {
          score += 5;

          if (daysUntilExpiry == null ||
              days < daysUntilExpiry) {
            expiringIngredient =
                pantryItem.name;

            daysUntilExpiry = days;
          }
        }

        // Medium priority:
        // ingredient expires within 7 days.
        else if (days > 3 && days <= 7) {
          score += 3;

          if (daysUntilExpiry == null ||
              days < daysUntilExpiry) {
            expiringIngredient =
                pantryItem.name;

            daysUntilExpiry = days;
          }
        }
      }

      // ==========================================================
      // 5. ONLY RECOMMEND RECIPES WITH PANTRY MATCHES
      // ==========================================================

      if (matchedIngredients
          .isNotEmpty) {
        recommendations.add(
          RecipeRecommendation(
            recipe: recipe,
            matchedIngredients:
            matchedIngredients,
            score: score,
            expiringIngredient:
            expiringIngredient,
            daysUntilExpiry:
            daysUntilExpiry,
          ),
        );
      }
    }

    // ============================================================
    // 6. SORT BY HIGHEST SCORE
    // ============================================================

    recommendations.sort(
          (a, b) =>
          b.score.compareTo(a.score),
    );

    return recommendations;
  },
);

// ================================================================
// RECIPE RECOMMENDATION MODEL
// ================================================================

class RecipeRecommendation {
  const RecipeRecommendation({
    required this.recipe,
    required this.matchedIngredients,
    required this.score,
    this.expiringIngredient,
    this.daysUntilExpiry,
  });

  final Recipe recipe;

  /// Pantry items that match ingredients
  /// in this recipe.
  final List<String> matchedIngredients;

  /// Higher score means higher recommendation priority.
  final int score;

  /// Matched pantry item with the nearest expiry.
  final String? expiringIngredient;

  /// Number of days remaining until nearest expiry.
  final int? daysUntilExpiry;

  bool get hasExpiringIngredient =>
      expiringIngredient != null &&
          daysUntilExpiry != null;
}