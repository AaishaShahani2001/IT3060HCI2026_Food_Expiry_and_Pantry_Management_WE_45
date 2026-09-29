import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/recipe.dart';
import '../providers/recipe_providers.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _screenBackground =>
      _isDark ? const Color(0xFF121815) : AppColors.cream;

  Color get _cardColor =>
      _isDark ? const Color(0xFF1B2420) : AppColors.white;

  Color get _primaryText =>
      _isDark ? const Color(0xFFF1F5F3) : AppColors.darkGreen;

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB8C2BD) : AppColors.textSecondary;

  Color get _borderColor =>
      _isDark ? const Color(0xFF34423B) : AppColors.cardBorder;

  Color get _softGreenColor =>
      _isDark ? const Color(0xFF1E3A2C) : AppColors.softGreen;

  Color get _inputColor =>
      _isDark ? const Color(0xFF202A25) : _cardColor;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final filteredRecipes = ref.watch(filteredRecipesProvider);
    final summary = ref.watch(recipeSummaryProvider);
    final filters = ref.watch(recipeFilterProvider);
    final recommendations = ref.watch(recommendedRecipesProvider);

    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        title: const Text(
          'Recipes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _screenBackground,
        foregroundColor: _primaryText,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Clear filters',
            onPressed: filters.hasActiveFilters
                ? () {
              ref.read(recipeFilterProvider.notifier).clearFilters();

              _searchController.clear();
              setState(() {});
            }
                : null,
            icon: Icon(Icons.filter_alt_off_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return ref.read(recipesProvider.notifier).refreshRecipes();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            _buildSummary(summary),

            const SizedBox(height: 18),

            _buildSearchField(),

            const SizedBox(height: 12),

            _buildFilters(filters),

            const SizedBox(height: 18),

            if (recommendations.isNotEmpty) ...[
              _buildRecommendationSection(recommendations),
              const SizedBox(height: 24),
            ],

            recipesAsync.when(
              data: (_) => _buildRecipeList(filteredRecipes),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _buildErrorState(error),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary(({int total, int favorites}) summary) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Recipes',
            value: summary.total.toString(),
            icon: Icons.restaurant_menu_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            title: 'Favorites',
            value: summary.favorites.toString(),
            icon: Icons.favorite_outline,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _softGreenColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.mediumGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        ref.read(recipeFilterProvider.notifier).setSearchQuery(value.trim());

        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Search recipes',
        prefixIcon: Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
          onPressed: () {
            _searchController.clear();

            ref.read(recipeFilterProvider.notifier).setSearchQuery('');

            setState(() {});
          },
          icon: Icon(Icons.clear),
        )
            : null,
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters(RecipeFilterState filters) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<RecipeCategory?>(
            initialValue: filters.category,
            decoration: InputDecoration(
              labelText: 'Category',
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
            ),
            items: [
              const DropdownMenuItem<RecipeCategory?>(
                value: null,
                child: Text('All categories'),
              ),
              ...RecipeCategory.values.map(
                    (category) => DropdownMenuItem<RecipeCategory?>(
                  value: category,
                  child: Text(category.label),
                ),
              ),
            ],
            onChanged: (value) {
              ref.read(recipeFilterProvider.notifier).setCategory(value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _borderColor),
            ),
            tileColor: _cardColor,
            title: const Text(
              'Favorites',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            value: filters.favoritesOnly,
            onChanged: (value) {
              ref.read(recipeFilterProvider.notifier).setFavoritesOnly(value);
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECIPE LIST
  // ============================================================

  Widget _buildRecipeList(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return _buildEmptyState();
    }

    return Column(children: recipes.map(_buildRecipeCard).toList());
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showRecipeDetails(recipe),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: recipe.isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    onPressed: () {
                      ref
                          .read(recipesProvider.notifier)
                          .toggleFavorite(recipe.id);
                    },
                    icon: Icon(
                      recipe.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: recipe.isFavorite
                          ? AppColors.statusRed
                          : _secondaryText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                recipe.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryText,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _recipeTag(Icons.category_outlined, recipe.category.label),
                  const SizedBox(width: 8),
                  _recipeTag(
                    Icons.schedule_outlined,
                    '${recipe.preparationTime} min',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECOMMENDATIONS
  // ============================================================

  Widget _buildRecommendationSection(
      List<RecipeRecommendation> recommendations,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _softGreenColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 20,
                color: AppColors.mediumGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended for You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primaryText,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Recipes based on your available food & Based on your pantry, preferences & allergies',
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        ...recommendations.take(3).map(_buildRecommendationCard),
      ],
    );
  }

  Widget _buildRecommendationCard(RecipeRecommendation recommendation) {
    final recipe = recommendation.recipe;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecipeDetails(recipe),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primaryText,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: _secondaryText,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                recipe.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: _secondaryText,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _recipeTag(
                    Icons.inventory_2_outlined,
                    recommendation.matchedIngredients.join(', '),
                  ),

                  if (recommendation.hasExpiringIngredient)
                    _expiryWarningTag(
                      recommendation.daysUntilExpiry == 0
                          ? '${recommendation.expiringIngredient} expires today'
                          : '${recommendation.expiringIngredient} expires in ${recommendation.daysUntilExpiry} day${recommendation.daysUntilExpiry == 1 ? '' : 's'}',
                      isToday: recommendation.daysUntilExpiry == 0,
                    ),

                  _recipeTag(
                    Icons.schedule_outlined,
                    '${recipe.preparationTime} min',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recipeTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _softGreenColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.mediumGreen),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mediumGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expiryWarningTag(
      String text, {
        required bool isToday,
      }) {
    final backgroundColor = isToday
        ? const Color(0xFFFDE8E7)
        : const Color(0xFFFFF4D6);

    final iconColor = isToday
        ? const Color(0xFFC62828)
        : const Color(0xFFD88900);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: iconColor,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECIPE DETAILS
  // ============================================================

  Future<void> _showRecipeDetails(Recipe recipe) async {
    final recommendations = ref.read(recommendedRecipesProvider);

    RecipeRecommendation? recommendation;

    for (final item in recommendations) {
      if (item.recipe.id == recipe.id) {
        recommendation = item;
        break;
      }
    }

    final matchedIngredients =
        recommendation?.matchedIngredients ?? const <String>[];

    final matchedCount = matchedIngredients.length;

    final totalIngredients = recipe.ingredients.length;

    final matchPercentage = totalIngredients == 0
        ? 0
        : ((matchedCount / totalIngredients) * 100).round();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.97,
            decoration: BoxDecoration(
              color: _screenBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // ==================================================
                // TOP BAR
                // ==================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      _detailIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                      ),

                      Expanded(
                        child: Center(
                          child: Text(
                            'Recipe Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _primaryText,
                            ),
                          ),
                        ),
                      ),

                      _detailIconButton(
                        icon: recipe.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: recipe.isFavorite
                            ? AppColors.statusRed
                            : AppColors.statusRed,
                        onPressed: () {
                          ref
                              .read(recipesProvider.notifier)
                              .toggleFavorite(recipe.id);

                          Navigator.pop(sheetContext);
                        },
                      ),

                      const SizedBox(width: 7),

                      _detailIconButton(
                        icon: Icons.share_outlined,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Recipe sharing will be connected here.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // SCROLLABLE CONTENT
                // ==================================================
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==================================================
                        // HERO
                        // ==================================================

                        _buildRecipeHeroImage(recipe),

                        const SizedBox(height: 14),

                        // ==================================================
                        // TITLE
                        // ==================================================
                        Text(
                          recipe.name,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: _primaryText,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 9),

                        // ==================================================
                        // META
                        // ==================================================
                        _buildRecipeMetadata(recipe),

                        const SizedBox(height: 10),

                        // ==================================================
                        // DESCRIPTION
                        // ==================================================
                        Text(
                          recipe.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.55,
                            color: _secondaryText,
                          ),
                        ),

                        // ==================================================
                        // PANTRY MATCH
                        // ==================================================
                        if (matchedCount > 0) ...[
                          const SizedBox(height: 14),
                          _buildPantryMatchCard(
                            matchedCount: matchedCount,
                            totalIngredients: totalIngredients,
                            matchPercentage: matchPercentage,
                            recommendation: recommendation,
                          ),
                        ],

                        const SizedBox(height: 22),

                        // ==================================================
                        // INGREDIENT HEADER
                        // ==================================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Ingredients',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '(${recipe.ingredients.length} items)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Tap to check off',
                              style: TextStyle(
                                fontSize: 10,
                                color: _secondaryText,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 11),

                        // ==================================================
                        // INGREDIENT GRID
                        // ==================================================
                        _buildIngredientGrid(
                          recipe: recipe,
                          matchedIngredients: matchedIngredients,
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // ADD MISSING INGREDIENT
                        // ==================================================
                        _buildAddMissingIngredientButton(
                          recipe: recipe,
                          matchedIngredients: matchedIngredients,
                        ),

                        const SizedBox(height: 22),

                        // ==================================================
                        // INSTRUCTIONS
                        // ==================================================
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _primaryText,
                          ),
                        ),

                        const SizedBox(height: 11),

                        _buildInstructionList(recipe),
                      ],
                    ),
                  ),
                ),

                // ==================================================
                // FIXED START COOKING BUTTON
                // ==================================================
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  decoration: BoxDecoration(
                    color: _screenBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showCookingMode(recipe);
                      },
                      icon: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Start Cooking Mode',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HERO IMAGE
  // ============================================================

  Widget _buildRecipeHeroImage(Recipe recipe) {
    return SizedBox(
      height: 205,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.network(
                _imageForRecipe(recipe),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: _softGreenColor,
                    child: const Center(
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        size: 54,
                        color: AppColors.mediumGreen,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom gradient
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Category chip
          Positioned(
            left: 12,
            bottom: 10,
            child: _heroChip(
              icon: Icons.restaurant_outlined,
              text: recipe.category.label,
            ),
          ),

          // Time chip
          Positioned(
            left: 102,
            bottom: 10,
            child: _heroChip(
              icon: Icons.schedule_outlined,
              text: '${recipe.preparationTime} min',
            ),
          ),

          // Difficulty chip
          Positioned(
            right: 10,
            bottom: 10,
            child: _heroChip(text: _difficultyForRecipe(recipe)),
          ),
        ],
      ),
    );
  }

  Widget _heroChip({IconData? icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _screenBackground,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _primaryText),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _primaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE SELECTION
  // ============================================================

  String _imageForRecipe(Recipe recipe) {
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

  // ============================================================
  // RECIPE METADATA
  // ============================================================

  Widget _buildRecipeMetadata(Recipe recipe) {
    return Row(
      children: [
        _metadataItem(
          Icons.star_rounded,
          '4.8',
          iconColor: const Color(0xFFE8A317),
        ),

        const SizedBox(width: 5),

        Text(
          '(124)',
          style: TextStyle(fontSize: 10, color: _secondaryText),
        ),

        const SizedBox(width: 13),

        _metadataItem(
          Icons.local_fire_department_outlined,
          '${_caloriesForRecipe(recipe)} kcal',
        ),

        const SizedBox(width: 13),

        _metadataItem(
          Icons.people_outline,
          '${_servingsForRecipe(recipe)} servings',
        ),
      ],
    );
  }

  Widget _metadataItem(IconData icon, String text, {Color? iconColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor ?? AppColors.mediumGreen),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _secondaryText,
          ),
        ),
      ],
    );
  }

  String _difficultyForRecipe(Recipe recipe) {
    if (recipe.preparationTime <= 15) {
      return 'Easy';
    }

    if (recipe.preparationTime <= 35) {
      return 'Medium';
    }

    return 'Hard';
  }

  int _servingsForRecipe(Recipe recipe) {
    if (recipe.ingredients.length <= 4) {
      return 1;
    }

    if (recipe.ingredients.length <= 7) {
      return 2;
    }

    return 4;
  }

  int _caloriesForRecipe(Recipe recipe) {
    final name = recipe.name.toLowerCase();

    if (name.contains('salad')) {
      return 280;
    }

    if (name.contains('rice')) {
      return 320;
    }

    if (name.contains('pasta')) {
      return 410;
    }

    if (name.contains('chicken')) {
      return 390;
    }

    if (name.contains('soup')) {
      return 240;
    }

    if (name.contains('sandwich')) {
      return 350;
    }

    return 300;
  }

  // ============================================================
  // PANTRY MATCH CARD
  // ============================================================

  Widget _buildPantryMatchCard({
    required int matchedCount,
    required int totalIngredients,
    required int matchPercentage,
    required RecipeRecommendation? recommendation,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E3A2C) : const Color(0xFFEAF5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.mediumGreen.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _primaryText,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$matchedCount of $totalIngredients ingredients in your pantry',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _primaryText,
                  ),
                ),

                if (recommendation?.hasExpiringIngredient == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    recommendation!.daysUntilExpiry == 0
                        ? '${recommendation.expiringIngredient} expires today'
                        : '${recommendation.expiringIngredient} expires in ${recommendation.daysUntilExpiry} day${recommendation.daysUntilExpiry == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: recommendation.daysUntilExpiry == 0
                          ? const Color(0xFFC62828)
                          : const Color(0xFFD88900),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$matchPercentage% Match',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.mediumGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INGREDIENT GRID
  // ============================================================

  Widget _buildIngredientGrid({
    required Recipe recipe,
    required List<String> matchedIngredients,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recipe.ingredients.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 60,
      ),
      itemBuilder: (context, index) {
        final ingredient = recipe.ingredients[index];

        final isAvailable = _ingredientIsAvailable(
          ingredient,
          matchedIngredients,
        );

        return _ingredientCard(
          ingredient: ingredient,
          isAvailable: isAvailable,
        );
      },
    );
  }

  bool _ingredientIsAvailable(
      String ingredient,
      List<String> matchedIngredients,
      ) {
    final ingredientName = ingredient.trim().toLowerCase();

    return matchedIngredients.any((matched) {
      final pantryName = matched.trim().toLowerCase();

      return ingredientName.contains(pantryName) ||
          pantryName.contains(ingredientName);
    });
  }

  Widget _ingredientCard({
    required String ingredient,
    required bool isAvailable,
  }) {
    final parsed = _parseIngredient(ingredient);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isAvailable ? _borderColor : const Color(0xFFE9C86A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: isAvailable ? _primaryText : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isAvailable
                    ? _primaryText
                    : const Color(0xFFE9C86A),
              ),
            ),
            child: isAvailable
                ? Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isAvailable
                        ? _primaryText
                        : _primaryText,
                  ),
                ),

                if (parsed.$2.isNotEmpty)
                  Text(
                    parsed.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      color: _secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Keeps the original ingredient text intact.
  /// If the text contains " - ", the left side is treated
  /// as the main ingredient and the right side as its detail.
  (String, String) _parseIngredient(String ingredient) {
    final parts = ingredient.split(' - ');

    if (parts.length >= 2) {
      return (parts.first.trim(), parts.sublist(1).join(' - ').trim());
    }

    return (ingredient.trim(), '');
  }

  // ============================================================
  // ADD MISSING INGREDIENT
  // ============================================================

  Widget _buildAddMissingIngredientButton({
    required Recipe recipe,
    required List<String> matchedIngredients,
  }) {
    final missingIngredients = recipe.ingredients
        .where(
          (ingredient) =>
      !_ingredientIsAvailable(ingredient, matchedIngredients),
    )
        .toList();

    if (missingIngredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await _addMissingIngredientsToShoppingList(missingIngredients);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: AppColors.mediumGreen,
            ),
            const SizedBox(width: 5),
            Text(
              'Add ${missingIngredients.length} missing '
                  'ingredient${missingIngredients.length == 1 ? '' : 's'} '
                  'to Shopping List',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMissingIngredientsToShoppingList(
      List<String> missingIngredients,
      ) async {
    if (missingIngredients.isEmpty) {
      return;
    }

    final shoppingNotifier = ref.read(shoppingListProvider.notifier);

    var addedCount = 0;
    var alreadyExistsCount = 0;
    var failedCount = 0;

    for (final ingredient in missingIngredients) {
      final shoppingName = _shoppingIngredientName(ingredient);

      if (shoppingName.trim().isEmpty) {
        continue;
      }

      try {
        await shoppingNotifier.addItem(
          ShoppingItem(name: shoppingName, quantity: 1, source: 'recipe'),
        );

        addedCount++;
      } on ShoppingDuplicateException {
        // The Shopping List already contains this item.
        // Do not create another duplicate.
        alreadyExistsCount++;
      } on ShoppingQuantityLimitException {
        failedCount++;
      } catch (_) {
        failedCount++;
      }
    }

    if (!mounted) {
      return;
    }

    String message;

    if (addedCount > 0 && alreadyExistsCount == 0 && failedCount == 0) {
      message =
      '$addedCount ingredient${addedCount == 1 ? '' : 's'} '
          'added to Shopping List';
    } else if (addedCount > 0) {
      message =
      '$addedCount added'
          '${alreadyExistsCount > 0 ? ', $alreadyExistsCount already on your list' : ''}'
          '${failedCount > 0 ? ', $failedCount failed' : ''}';
    } else if (alreadyExistsCount > 0 && failedCount == 0) {
      message =
      'The missing ingredient${alreadyExistsCount == 1 ? '' : 's'} '
          'is already on your Shopping List';
    } else {
      message = 'Could not add the missing ingredients to your Shopping List';
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  String _shoppingIngredientName(String ingredient) {
    final trimmed = ingredient.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    // This keeps the Shopping List readable while preserving
    // the ingredient text used by the Recipe screen.
    final parts = trimmed.split(' - ');

    if (parts.isNotEmpty) {
      return parts.first.trim();
    }

    return trimmed;
  }
  // ============================================================
  // INSTRUCTIONS
  // ============================================================

  Widget _buildInstructionList(Recipe recipe) {
    return Column(
      children: recipe.instructions.asMap().entries.map((entry) {
        final stepNumber = entry.key + 1;

        final instruction = entry.value.trim();

        final parsed = _parseInstruction(instruction);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _softGreenColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _primaryText,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parsed.$1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _primaryText,
                      ),
                    ),

                    if (parsed.$2.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        parsed.$2,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.45,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  (String, String) _parseInstruction(String instruction) {
    final words = instruction.split(RegExp(r'\s+'));

    if (words.length <= 5) {
      return (instruction, '');
    }

    final title = words.take(4).join(' ');

    final description = words.skip(4).join(' ');

    return (title, description);
  }

  // ============================================================
  // DETAIL ICON BUTTON
  // ============================================================

  Widget _detailIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: iconColor ?? _secondaryText),
      ),
    );
  }

  // ============================================================
  // COOKING MODE
  // ============================================================

  void _showCookingMode(Recipe recipe) {
    Navigator.pop(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.97,
            decoration: BoxDecoration(
              color: _screenBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      _detailIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                      ),

                      Expanded(
                        child: Center(
                          child: Text(
                            'Cooking Mode',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _primaryText,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 36),
                    ],
                  ),
                ),

                // ==================================================
                // CONTENT
                // ==================================================
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _primaryText,
                          ),
                        ),

                        const SizedBox(height: 9),

                        Row(
                          children: [
                            _heroChip(
                              icon: Icons.schedule_outlined,
                              text: '${recipe.preparationTime} min',
                            ),
                            const SizedBox(width: 7),
                            _heroChip(text: _difficultyForRecipe(recipe)),
                          ],
                        ),

                        const SizedBox(height: 22),

                        ...recipe.instructions.asMap().entries.map((entry) {
                          final step = entry.key + 1;

                          final parsed = _parseInstruction(entry.value.trim());

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 27,
                                  height: 27,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _primaryText,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$step',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        parsed.$1,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryText,
                                        ),
                                      ),

                                      if (parsed.$2.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          parsed.$2,
                                          style: TextStyle(
                                            fontSize: 10,
                                            height: 1.4,
                                            color: _secondaryText,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // ==================================================
                // FINISH BUTTON
                // ==================================================
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  decoration: BoxDecoration(
                    color: _screenBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                      icon: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Finish Cooking',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final filters = ref.read(recipeFilterProvider);

    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(
            filters.hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.restaurant_menu_outlined,
            size: 52,
            color: AppColors.mediumGreen,
          ),

          const SizedBox(height: 14),

          Text(
            filters.hasActiveFilters
                ? 'No matching recipes'
                : 'No recipes available',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _primaryText,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            filters.hasActiveFilters
                ? 'Try changing your search or filters.'
                : 'Recipes will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(Object error) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 46, color: AppColors.statusRed),

          const SizedBox(height: 12),

          Text(
            'Unable to load recipes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _primaryText,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _secondaryText,
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () {
              ref.read(recipesProvider.notifier).refreshRecipes();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

