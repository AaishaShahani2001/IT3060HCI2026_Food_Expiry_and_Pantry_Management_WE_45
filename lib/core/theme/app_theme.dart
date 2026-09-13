import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: AppColors.white,
      surface: AppColors.cream,
      onSurface: AppColors.darkGreen,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.cardBorder,
      surfaceContainerHighest: AppColors.white,
      secondaryContainer: AppColors.softGreen,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.cream,
      headlineColor: AppColors.darkGreen,
      bodyColor: AppColors.textSecondary,
      textButtonColor: AppColors.mediumGreen,
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.dark,
      primary: AppColors.primaryGreen,
      onPrimary: AppColors.white,
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorder,
      surfaceContainerHighest: AppColors.darkCard,
      secondaryContainer: AppColors.darkIconBg,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.darkBackground,
      headlineColor: AppColors.darkTextPrimary,
      bodyColor: AppColors.darkTextSecondary,
      textButtonColor: AppColors.primaryGreen,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color headlineColor,
    required Color bodyColor,
    required Color textButtonColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: headlineColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: headlineColor,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      cardColor: colorScheme.surfaceContainerHighest,
      dividerColor: colorScheme.outline,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: headlineColor,
          fontWeight: FontWeight.w700,
          fontSize: 26,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: headlineColor,
          fontWeight: FontWeight.w700,
          fontSize: 32,
          letterSpacing: -0.4,
        ),
        bodyLarge: TextStyle(color: bodyColor, fontSize: 16, height: 1.5),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textButtonColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
