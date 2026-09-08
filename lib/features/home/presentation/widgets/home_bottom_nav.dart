import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: 0.08),
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
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.textSecondary,
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: AppColors.primaryGreen),
              label: AppStrings.navHome,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.kitchen_outlined),
              activeIcon: Icon(Icons.kitchen, color: AppColors.primaryGreen),
              label: AppStrings.navPantry,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_busy_outlined),
              activeIcon: Icon(Icons.event_busy, color: AppColors.primaryGreen),
              label: AppStrings.navExpiry,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(
                Icons.shopping_cart,
                color: AppColors.primaryGreen,
              ),
              label: AppStrings.navShopping,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(
                Icons.restaurant_menu,
                color: AppColors.primaryGreen,
              ),
              label: AppStrings.navRecipes,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings, color: AppColors.primaryGreen),
              label: AppStrings.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
