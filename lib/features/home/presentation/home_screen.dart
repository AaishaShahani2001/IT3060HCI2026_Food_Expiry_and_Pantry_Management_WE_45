import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';

import 'widgets/home_header.dart';
import 'widgets/summary_card.dart';
import 'widgets/welcome_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeHeader(),
              const SizedBox(height: 20),
              const WelcomeSection(),
              const SizedBox(height: 24),
              Text(
                'Overview',
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: AppStrings.pantryItems,
                value: '24 Items',
                icon: Icons.kitchen_outlined,
                onTap: () => context.go(AppRoutes.pantry),
              ),
              const SizedBox(height: 10),
              SummaryCard(
                title: AppStrings.expiringSoon,
                value: '3 Items',
                icon: Icons.event_busy_outlined,
                iconColor: Colors.orange.shade700,
                onTap: () => context.go(AppRoutes.expiry),
              ),
              const SizedBox(height: 10),
              SummaryCard(
                title: AppStrings.shoppingList,
                value: '5 Needed',
                icon: Icons.shopping_cart_outlined,
                onTap: () => context.go(AppRoutes.shopping),
              ),
              const SizedBox(height: 10),
              SummaryCard(
                title: AppStrings.recipeSuggestions,
                value: '8 Ready',
                icon: Icons.restaurant_menu_outlined,
                onTap: () => context.go(AppRoutes.recipes),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
