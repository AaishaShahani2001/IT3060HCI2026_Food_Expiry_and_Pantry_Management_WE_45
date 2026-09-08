import 'package:go_router/go_router.dart';

import '../../features/expiry/presentation/screens/expiry_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/widgets/home_shell.dart';
import '../../features/home/presentation/widgets/section_placeholder.dart';
import '../../features/pantry/presentation/screens/pantry_screen.dart';
import '../../features/shopping/presentation/screens/shopping_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/Authentication/screens/login_screen.dart';
import '../../features/Authentication/screens/signup_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/change_password_screen.dart';
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
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.pantry,
          builder: (context, state) => const PantryScreen(),
        ),
        GoRoute(
          path: AppRoutes.expiry,
          builder: (context, state) => const ExpiryScreen(),
        ),
        GoRoute(
          path: AppRoutes.shopping,
          builder: (context, state) => const ShoppingScreen(),
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
