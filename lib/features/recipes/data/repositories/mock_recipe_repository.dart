import '../../domain/models/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';

class MockRecipeRepository implements RecipeRepository {
  MockRecipeRepository({List<Recipe>? initialRecipes})
    : _recipes = List<Recipe>.from(initialRecipes ?? _seedRecipes);

  final List<Recipe> _recipes;

  int _idCounter = 100;

  static final List<Recipe> _seedRecipes = [
    Recipe(
      id: '1',
      name: 'Vegetable Fried Rice',
      description: 'A quick fried rice using fresh vegetables and cooked rice.',
      category: RecipeCategory.lunch,
      preparationTime: 25,
      ingredients: [
        'Cooked rice',
        'Carrot',
        'Green peas',
        'Eggs',
        'Soy sauce',
        'Spring onions',
      ],
      instructions: [
        'Heat a pan and add a small amount of oil.',
        'Cook the vegetables until slightly tender.',
        'Add the eggs and scramble them.',
        'Add the cooked rice and soy sauce.',
        'Stir-fry everything for a few minutes.',
        'Garnish with spring onions and serve.',
      ],
    ),
    Recipe(
      id: '2',
      name: 'Chicken Rice Bowl',
      description: 'A simple chicken and rice meal for a filling dinner.',
      category: RecipeCategory.dinner,
      preparationTime: 35,
      ingredients: [
        'Chicken',
        'Rice',
        'Carrot',
        'Soy sauce',
        'Garlic',
        'Pepper',
      ],
      instructions: [
        'Cook the rice according to the package instructions.',
        'Season the chicken with garlic and pepper.',
        'Cook the chicken until fully done.',
        'Slice the cooked chicken.',
        'Serve the chicken over rice with vegetables.',
      ],
    ),
    Recipe(
      id: '3',
      name: 'Apple Yogurt Bowl',
      description: 'A quick and healthy breakfast using apples and yogurt.',
      category: RecipeCategory.breakfast,
      preparationTime: 10,
      ingredients: ['Apples', 'Yogurt', 'Honey', 'Granola'],
      instructions: [
        'Wash and slice the apples.',
        'Add yogurt to a bowl.',
        'Place the sliced apples on top.',
        'Add granola and a small amount of honey.',
        'Serve immediately.',
      ],
    ),
    Recipe(
      id: '4',
      name: 'Creamy Spinach Pasta',
      description: 'A simple pasta dish with creamy spinach sauce.',
      category: RecipeCategory.dinner,
      preparationTime: 30,
      ingredients: [
        'Pasta',
        'Spinach',
        'Milk',
        'Cheese',
        'Garlic',
        'Olive oil',
      ],
      instructions: [
        'Cook the pasta until tender.',
        'Heat olive oil and garlic in a pan.',
        'Add spinach and cook until wilted.',
        'Add milk and cheese.',
        'Stir until the sauce becomes creamy.',
        'Mix the pasta with the sauce and serve.',
      ],
    ),
    Recipe(
      id: '5',
      name: 'Fresh Fruit Snack',
      description: 'A quick snack made from available fresh fruits.',
      category: RecipeCategory.snack,
      preparationTime: 5,
      ingredients: ['Apples', 'Banana', 'Orange'],
      instructions: [
        'Wash all fruits thoroughly.',
        'Peel and cut the fruits into small pieces.',
        'Mix the fruits in a bowl.',
        'Serve fresh.',
      ],
    ),
    Recipe(
      id: '6',
      name: 'Vegetable Sandwich',
      description: 'A quick sandwich using vegetables and cheese.',
      category: RecipeCategory.snack,
      preparationTime: 15,
      ingredients: ['Bread', 'Tomato', 'Spinach', 'Cheese', 'Olive oil'],
      instructions: [
        'Slice the vegetables.',
        'Place cheese and vegetables between two slices of bread.',
        'Lightly toast the sandwich.',
        'Serve while warm.',
      ],
    ),
  ];

  @override
  Future<List<Recipe>> fetchRecipes() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return List<Recipe>.from(_recipes);
  }

  @override
  Future<Recipe> addRecipe(Recipe recipe) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final newRecipe = recipe.copyWith(
      id: recipe.id.isEmpty ? '${++_idCounter}' : recipe.id,
    );

    _recipes.insert(0, newRecipe);

    return newRecipe;
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final index = _recipes.indexWhere((entry) => entry.id == recipe.id);

    if (index == -1) {
      throw StateError('Recipe not found.');
    }

    _recipes[index] = recipe;

    return recipe;
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    _recipes.removeWhere((recipe) => recipe.id == id);
  }
}
