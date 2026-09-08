import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';

class SectionPlaceholder extends StatelessWidget {
  final String title;

  const SectionPlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            color: AppColors.darkGreen,
          ),
        ),
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                    color: AppColors.darkGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.sectionComingSoon,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
