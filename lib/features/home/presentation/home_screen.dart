import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';

import '../../expiry/presentation/providers/expiry_provider.dart';
import '../../pantry/presentation/providers/pantry_providers.dart';
import 'widgets/home_header.dart';
import 'widgets/summary_card.dart';
import 'widgets/welcome_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final pantrySummary = ref.watch(pantrySummaryProvider);
    final expirySummary = ref.watch(expirySummaryProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeHeader(),

              const SizedBox(height: 16),

              // PROFILE BUTTON
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(AppRoutes.profile),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD5E7DC)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF2E6B4E),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Profile',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F4D38),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Manage your preferences and pantry type',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Color(0xFF2E6B4E),
                      ),
                    ],
                  ),
                ),
              ),

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
                value: _itemCountLabel(pantrySummary.total),
                icon: Icons.kitchen_outlined,
                onTap: () => context.go(AppRoutes.pantry),
              ),

              const SizedBox(height: 10),

              SummaryCard(
                title: AppStrings.expiringSoon,
                value: _itemCountLabel(expirySummary.expiringSoon),
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

  String _itemCountLabel(int count) {
    return count == 1 ? '1 Item' : '$count Items';
  }
}
