import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';

class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({super.key});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.pantry)) return 1;
    if (location.startsWith(AppRoutes.expiry)) return 2;
    if (location.startsWith(AppRoutes.shopping)) return 3;
    if (location.startsWith(AppRoutes.recipes)) return 4;
    if (location.startsWith(AppRoutes.settings)) return 5;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    final selectedIndex = _calculateSelectedIndex(context);
    if (selectedIndex == index) return;

    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.pantry);
        break;
      case 2:
        context.go(AppRoutes.expiry);
        break;
      case 3:
        context.go(AppRoutes.shopping);
        break;
      case 4:
        context.go(AppRoutes.recipes);
        break;
      case 5:
        context.go(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = colorScheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => _onItemTapped(context, index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: barColor,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: colorScheme.primary),
              label: AppStrings.navHome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.kitchen_outlined),
              activeIcon: Icon(Icons.kitchen, color: colorScheme.primary),
              label: AppStrings.navPantry,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.event_busy_outlined),
              activeIcon: Icon(Icons.event_busy, color: colorScheme.primary),
              label: AppStrings.navExpiry,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(
                Icons.shopping_cart,
                color: colorScheme.primary,
              ),
              label: AppStrings.navShopping,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(
                Icons.restaurant_menu,
                color: colorScheme.primary,
              ),
              label: AppStrings.navRecipes,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings, color: colorScheme.primary),
              label: AppStrings.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
