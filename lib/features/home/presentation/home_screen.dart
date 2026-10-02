import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';

import 'widgets/home_expiry_soon_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_pantry_summary_card.dart';
import 'widgets/home_recent_recipes_section.dart';
import 'widgets/welcome_section.dart';
import 'widgets/home_waste_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeHeader(),

              const SizedBox(height: 16),

              const WelcomeSection(),

              const SizedBox(height: 20),

              // PROFILE BUTTON
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(AppRoutes.profile),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Profile',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Manage your preferences and pantry type',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // THIS MONTH WASTE TRACKER SUMMARY CARD
              const HomeWasteSummaryCard(),

              const SizedBox(height: 20),

              const HomeQuickActions(),

              const SizedBox(height: 20),

              // YOUR PANTRY SECTION — Modern 2-stat overview card
              const HomePantrySummaryCard(),

              const SizedBox(height: 24),

              const HomeExpirySoonSection(),

              const SizedBox(height: 24),

              const HomeRecentRecipesSection(),
            ],
          ),
        ),
      ),
    );
  }
}
