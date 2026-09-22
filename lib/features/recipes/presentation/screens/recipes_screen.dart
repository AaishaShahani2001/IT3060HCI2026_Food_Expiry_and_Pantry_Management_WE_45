import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/recipe.dart';
import '../providers/recipe_providers.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recipes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
            icon: const Icon(Icons.filter_alt_off_outlined),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.secondary, size: 22),
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
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
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

  Widget _buildSearchField() {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: _searchController,
      onChanged: (value) {
        ref.read(recipeFilterProvider.notifier).setSearchQuery(value.trim());

        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Search recipes',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();

                  ref.read(recipeFilterProvider.notifier).setSearchQuery('');

                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilters(RecipeFilterState filters) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<RecipeCategory?>(
            initialValue: filters.category,
            dropdownColor: colorScheme.surfaceContainerHighest,
            decoration: InputDecoration(
              labelText: 'Category',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.outline),
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
              side: BorderSide(color: colorScheme.outline),
            ),
            tileColor: colorScheme.surfaceContainerHighest,
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

  Widget _buildRecipeList(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return _buildEmptyState();
    }

    return Column(children: recipes.map(_buildRecipeCard).toList());
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline),
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
                        color: colorScheme.onSurface,
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
                          : colorScheme.onSurfaceVariant,
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
                  color: colorScheme.onSurfaceVariant,
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

  Widget _recipeTag(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.secondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final filters = ref.read(recipeFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(
            filters.hasActiveFilters
                ? Icons.search_off_rounded
                : Icons.restaurant_menu_outlined,
            size: 52,
            color: colorScheme.secondary,
          ),
          const SizedBox(height: 14),
          Text(
            filters.hasActiveFilters
                ? 'No matching recipes'
                : 'No recipes available',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            filters.hasActiveFilters
                ? 'Try changing your search or filters.'
                : 'Recipes will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 46, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Unable to load recipes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
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

  Future<void> _showRecipeDetails(Recipe recipe) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      builder: (context) {
        final sheetColors = Theme.of(context).colorScheme;

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: sheetColors.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ref
                                .read(recipesProvider.notifier)
                                .toggleFavorite(recipe.id);

                            Navigator.pop(context);
                          },
                          icon: Icon(
                            recipe.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: recipe.isFavorite
                                ? AppColors.statusRed
                                : sheetColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.description,
                      style: TextStyle(
                        color: sheetColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _recipeTag(
                          Icons.category_outlined,
                          recipe.category.label,
                        ),
                        const SizedBox(width: 8),
                        _recipeTag(
                          Icons.schedule_outlined,
                          '${recipe.preparationTime} min',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: sheetColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...recipe.ingredients.map(
                      (ingredient) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '•',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sheetColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ingredient,
                                style: TextStyle(
                                  color: sheetColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: sheetColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...recipe.instructions.asMap().entries.map((entry) {
                      final step = entry.key + 1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sheetColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '$step',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: sheetColors.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: sheetColors.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
