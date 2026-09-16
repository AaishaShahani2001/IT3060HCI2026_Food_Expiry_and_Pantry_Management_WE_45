import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/Authentication/Screens/login_screen.dart';
import '../../features/Authentication/Screens/signup_screen.dart';
import '../../features/expiry/presentation/screens/expiry_notification_settings_screen.dart';
import '../../features/expiry/presentation/screens/expiry_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/widgets/home_shell.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/pantry/presentation/screens/pantry_items_screen.dart';
import '../../features/pantry/presentation/screens/pantry_screen.dart';
import '../../features/profile/presentation/screens/change_password_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/recipes/presentation/screens/recipes_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shared_pantry/presentation/screens/shared_pantry_members_screen.dart';
import '../../features/shared_pantry/presentation/screens/shared_pantry_screen.dart';
import '../../features/shopping_list/models/shopping_item.dart';
import '../../features/shopping_list/presentation/screens/add_shopping_item_screen.dart';
import '../../features/shopping_list/presentation/screens/shopping_list_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

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
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignupScreen(),
    ),

    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),

    GoRoute(
      path: AppRoutes.changePassword,
      builder: (context, state) => const ChangePasswordScreen(),
    ),

    GoRoute(
      path: AppRoutes.sharedPantry,
      builder: (context, state) => const SharedPantryScreen(),
    ),

    GoRoute(
      path: AppRoutes.sharedPantryMembers,
      builder: (context, state) {
        final pantryId = state.uri.queryParameters['pantryId'];

        if (pantryId == null || pantryId.isEmpty) {
          return const Scaffold(body: Center(child: Text('Pantry not found.')));
        }

        return SharedPantryMembersScreen(pantryId: pantryId);
      },
    ),

    GoRoute(
      path: AppRoutes.addShoppingItem,
      builder: (context, state) =>
          AddShoppingItemScreen(initialItem: state.extra as ShoppingItem?),
    ),

    ShellRoute(
      builder: (context, state, child) {
        return HomeShell(child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),

        GoRoute(
          path: AppRoutes.pantry,
          builder: (context, state) => const PantryScreen(),
          routes: [
            GoRoute(
              // Child path is 'items', not '/items', so the location is /pantry/items.
              path: 'items',
              builder: (context, state) => const PantryItemsScreen(),
            ),
          ],
        ),

        GoRoute(
          path: AppRoutes.expiry,
          builder: (context, state) => const ExpiryScreen(),
        ),

        GoRoute(
          path: AppRoutes.expiryNotifications,
          builder: (context, state) => const ExpiryNotificationSettingsScreen(),
        ),

        GoRoute(
          path: AppRoutes.shopping,
          builder: (context, state) => const ShoppingListScreen(),
        ),

        GoRoute(
          path: AppRoutes.recipes,
          builder: (context, state) => const RecipesScreen(),
        ),

        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
