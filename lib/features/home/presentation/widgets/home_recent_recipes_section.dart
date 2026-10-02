import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../recipes/domain/models/recipe.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../../../recipes/presentation/utils/recipe_image.dart';
import 'home_section_header.dart';

/// Home preview of the recipes already returned by [recipesProvider].
///
/// The list keeps the repository order. Newly added recipes are inserted
/// at the front, and the model has no separate timestamp to sort by.
class HomeRecentRecipesSection extends ConsumerWidget {
  const HomeRecentRecipesSection({super.key});

  static const previewCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    final recipes = recipesAsync.asData?.value ?? const <Recipe>[];
    final preview = recipes.take(previewCount).toList();

    final body = switch (recipesAsync) {
      AsyncLoading() => const _RecipeStatus(
        message: 'Loading recipes',
        showProgress: true,
      ),
      AsyncError() => const _RecipeStatus(message: 'Couldn’t load recipes'),
      AsyncData() when preview.isEmpty => const _RecipeStatus(
        message: 'No recipes available yet',
        icon: Icons.restaurant_menu_outlined,
        showRecipesAction: true,
      ),
      AsyncData() => _RecentRecipeList(recipes: preview),
    };

    return Column(
      key: const ValueKey('home-recent-recipes-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RecentRecipesHeader(),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

class _RecentRecipesHeader extends StatelessWidget {
  const _RecentRecipesHeader();

  @override
  Widget build(BuildContext context) {
    return HomeSectionHeader(
      title: 'Recent Recipes',
      assetPath: 'assets/images/recipe-icon.jpg',
      fallbackIcon: Icons.restaurant_menu_outlined,
      animateIcon: false,
      onSeeAll: () => context.go(AppRoutes.recipes),
      semanticLabel: 'Recent Recipes',
    );
  }
}

class _RecipeStatus extends StatelessWidget {
  const _RecipeStatus({
    required this.message,
    this.icon,
    this.showProgress = false,
    this.showRecipesAction = false,
  });

  final String message;
  final IconData? icon;
  final bool showProgress;
  final bool showRecipesAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? FreshPalette.darkCard : FreshPalette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? FreshPalette.darkOutline.withValues(alpha: 0.6)
                : FreshPalette.outline.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            if (showProgress)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            else
              Icon(
                icon ?? Icons.cloud_off_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (showRecipesAction)
              TextButton(
                onPressed: () => context.go(AppRoutes.recipes),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colorScheme.primary,
                ),
                child: const Text('Open Recipes'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentRecipeList extends StatelessWidget {
  const _RecentRecipeList({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - 40;
    final cardWidth = ((available - 12) / 2.15).clamp(132.0, 188.0);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final imageHeight = cardWidth * 0.62;
    final cardHeight = imageHeight + (58 * textScale);

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _RecentRecipeCard(
            recipe: recipes[index],
            width: cardWidth,
            imageHeight: imageHeight,
          );
        },
      ),
    );
  }
}

class _RecentRecipeCard extends StatelessWidget {
  const _RecentRecipeCard({
    required this.recipe,
    required this.width,
    required this.imageHeight,
  });

  final Recipe recipe;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = '${recipe.preparationTime} min · ${recipe.category.label}';

    return Semantics(
      button: true,
      label: '${recipe.name}, $meta',
      child: SizedBox(
        width: width,
        child: Material(
          color: isDark ? FreshPalette.darkCard : FreshPalette.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => context.go(AppRoutes.recipes, extra: recipe),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? FreshPalette.darkOutline.withValues(alpha: 0.7)
                      : FreshPalette.outline.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: Image.network(
                        recipeDisplayImageUrl(recipe),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _RecipeImageFallback(isDark: isDark);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                color: colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                height: 1.1,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeImageFallback extends StatelessWidget {
  const _RecipeImageFallback({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fallbackColor = isDark
        ? Theme.of(context).colorScheme.primaryContainer
        : AppColors.softGreen;

    return ColoredBox(
      color: fallbackColor,
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 28,
          color: AppColors.mediumGreen,
        ),
      ),
    );
  }
}
