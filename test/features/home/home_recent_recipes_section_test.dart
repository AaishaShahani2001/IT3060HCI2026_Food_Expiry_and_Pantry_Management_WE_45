import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/home_screen.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_expiry_soon_section.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_recent_recipes_section.dart';
import 'package:food_expiry_and_pantry_management/features/recipes/domain/models/recipe.dart';
import 'package:food_expiry_and_pantry_management/features/recipes/presentation/providers/recipe_providers.dart';
import 'package:go_router/go_router.dart';

import '../food_waste_tracking/support/waste_test_session.dart';
import 'package:food_expiry_and_pantry_management/core/providers/current_user_provider.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/pantry_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';

List<Recipe> _recipes = const [];
Completer<List<Recipe>>? _pending;

class _ScriptedRecipes extends RecipesNotifier {
  @override
  Future<List<Recipe>> build() async => _recipes;
}

class _LoadingRecipes extends RecipesNotifier {
  @override
  Future<List<Recipe>> build() => _pending!.future;
}

class _FailingRecipes extends RecipesNotifier {
  @override
  Future<List<Recipe>> build() async => throw Exception('offline');
}

class _EmptyPantry extends PantryItemsNotifier {
  @override
  Stream<List<PantryItem>> build() => Stream.value(const []);
}

class _TestUserName extends CurrentUserNameNotifier {
  @override
  Future<String> build() async => 'Test user';
}

Recipe _recipe(String id, String name) {
  return Recipe(
    id: id,
    name: name,
    description: 'A short description',
    ingredients: const ['Rice'],
    instructions: const ['Cook'],
    category: RecipeCategory.lunch,
    preparationTime: 25,
  );
}

void main() {
  late GoRouter router;

  setUp(() {
    _recipes = const [];
    _pending = null;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: HomeRecentRecipesSection()),
          ),
        ),
        GoRoute(
          path: AppRoutes.recipes,
          builder: (_, state) {
            final extra = state.extra;
            final label = extra is Recipe
                ? 'Recipe ${extra.id}'
                : 'Recipes destination';
            return Scaffold(body: Text(label));
          },
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<void> pumpSection(
    WidgetTester tester, {
    required RecipesNotifier Function() create,
    ThemeData? theme,
    Size size = const Size(360, 800),
    double scale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [recipesProvider.overrideWith(create)],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('shows the first recipes in existing order and opens them', (
    tester,
  ) async {
    _recipes = [
      _recipe('1', 'Vegetable Fried Rice'),
      _recipe('2', 'Chicken Rice Bowl'),
      _recipe('3', 'Apple Yogurt Bowl'),
      _recipe('4', 'Creamy Spinach Pasta'),
      _recipe('5', 'Fresh Fruit Snack'),
    ];
    await pumpSection(
      tester,
      create: _ScriptedRecipes.new,
      size: const Size(900, 800),
    );

    expect(find.text('Recent Recipes'), findsOneWidget);
    expect(find.text('Vegetable Fried Rice'), findsOneWidget);
    expect(find.text('Creamy Spinach Pasta'), findsOneWidget);
    expect(find.text('Fresh Fruit Snack'), findsNothing);
    expect(find.text('25 min · Lunch'), findsWidgets);

    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    expect(find.text('Recipes destination'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vegetable Fried Rice'));
    await tester.pumpAndSettle();
    expect(find.text('Recipe 1'), findsOneWidget);
  });

  testWidgets('empty, loading, and error stay inside the section', (
    tester,
  ) async {
    await pumpSection(tester, create: _ScriptedRecipes.new);
    expect(find.text('No recipes available yet'), findsOneWidget);
    await tester.tap(find.text('Open Recipes'));
    await tester.pumpAndSettle();
    expect(find.text('Recipes destination'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    _pending = Completer<List<Recipe>>();
    addTearDown(() {
      if (!_pending!.isCompleted) _pending!.complete(const []);
    });
    await pumpSection(tester, create: _LoadingRecipes.new, settle: false);
    expect(find.text('Loading recipes'), findsOneWidget);

    await pumpSection(tester, create: _FailingRecipes.new);
    expect(find.text('Couldn’t load recipes'), findsOneWidget);
  });

  testWidgets('fits a narrow phone in dark mode at large text', (tester) async {
    _recipes = [
      _recipe('1', 'Vegetable Fried Rice With A Very Long Name'),
      _recipe('2', 'Chicken Rice Bowl'),
    ];
    await pumpSection(
      tester,
      create: _ScriptedRecipes.new,
      theme: AppTheme.dark,
      size: const Size(320, 700),
      scale: 2,
    );
    expect(
      find.byKey(const ValueKey('home-recent-recipes-section')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home no longer shows Overview and lists recipes after expiry', (
    tester,
  ) async {
    final session = WasteTestSession();
    addTearDown(session.changes.close);
    final homeRouter = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: AppRoutes.wasteTracker,
          builder: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(homeRouter.dispose);
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _recipes = [_recipe('1', 'Vegetable Fried Rice')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserNameProvider.overrideWith(_TestUserName.new),
          pantryItemsProvider.overrideWith(_EmptyPantry.new),
          pantrySummaryProvider.overrideWithValue((total: 0, lowStock: 0)),
          expirySummaryProvider.overrideWithValue((
            total: 0,
            expired: 0,
            expiringSoon: 0,
            fresh: 0,
            unknown: 0,
          )),
          recipesProvider.overrideWith(_ScriptedRecipes.new),
          foodWasteRepositoryProvider.overrideWithValue(session.repository),
          wastePantryServiceProvider.overrideWithValue(session.pantry),
          wasteAuthUidProvider.overrideWith((ref) => session.auth()),
          wasteClockProvider.overrideWithValue(() => wasteTestNow),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: homeRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsNothing);
    expect(find.text('5 Needed'), findsNothing);
    expect(find.text('8 Ready'), findsNothing);
    expect(find.byType(HomeExpirySoonSection), findsOneWidget);
    expect(find.byType(HomeRecentRecipesSection), findsOneWidget);

    final expiryTop = tester.getTopLeft(find.byType(HomeExpirySoonSection)).dy;
    final recipesTop = tester
        .getTopLeft(find.byType(HomeRecentRecipesSection))
        .dy;
    expect(recipesTop, greaterThan(expiryTop));
  });
}
