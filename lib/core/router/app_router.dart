import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/widgets/home_shell.dart';
import '../../features/home/presentation/widgets/section_placeholder.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/shopping_list/models/shopping_item.dart';
import '../../features/shopping_list/presentation/screens/add_shopping_item_screen.dart';
import '../../features/shopping_list/presentation/screens/shopping_list_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../constants/app_strings.dart';
import 'app_routes.dart';

export 'app_routes.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.addShoppingItem,
      builder: (context, state) =>
          AddShoppingItemScreen(initialItem: state.extra as ShoppingItem?),
    ),
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.pantry,
          builder: (context, state) =>
              const SectionPlaceholder(title: AppStrings.navPantry),
        ),
        GoRoute(
          path: AppRoutes.expiry,
          builder: (context, state) =>
              const SectionPlaceholder(title: AppStrings.navExpiry),
        ),
        GoRoute(
          path: AppRoutes.shopping,
          builder: (context, state) => const ShoppingListScreen(),
        ),
        GoRoute(
          path: AppRoutes.recipes,
          builder: (context, state) =>
              const SectionPlaceholder(title: AppStrings.navRecipes),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) =>
              const SectionPlaceholder(title: AppStrings.navSettings),
        ),
      ],
    ),
  ],
);
