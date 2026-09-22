import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: FreshPalette.primaryButton,
      brightness: Brightness.light,
      primary: FreshPalette.primaryButton,
      onPrimary: FreshPalette.card,
      secondary: FreshPalette.selected,
      onSecondary: FreshPalette.card,
      tertiary: FreshPalette.highlight,
      onTertiary: FreshPalette.heading,
      primaryContainer: FreshPalette.highlight,
      onPrimaryContainer: FreshPalette.primaryButton,
      secondaryContainer: FreshPalette.accentSurface,
      onSecondaryContainer: FreshPalette.heading,
      surface: FreshPalette.pageBackground,
      onSurface: FreshPalette.heading,
      onSurfaceVariant: FreshPalette.secondaryText,
      outline: FreshPalette.outline,
      outlineVariant: const Color(0xFFE4EAE2),
      surfaceBright: FreshPalette.card,
      surfaceContainerLowest: FreshPalette.card,
      surfaceContainerLow: const Color(0xFFEEF2EA),
      surfaceContainer: const Color(0xFFE8EDE3),
      surfaceContainerHigh: const Color(0xFFE2E8DC),
      surfaceContainerHighest: FreshPalette.card,
      error: AppColors.statusRed,
      onError: FreshPalette.card,
      errorContainer: AppColors.statusRedBg,
      onErrorContainer: AppColors.statusRed,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: FreshPalette.pageBackground,
      headlineColor: FreshPalette.heading,
      bodyColor: FreshPalette.secondaryText,
      textButtonColor: FreshPalette.selected,
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: FreshPalette.primaryButton,
      brightness: Brightness.dark,
      // Slightly lifted green so buttons stay readable on dark surfaces.
      primary: FreshPalette.selected,
      onPrimary: FreshPalette.darkOnPrimary,
      // Highlight reads clearly as a selected/accent state on dark cards.
      secondary: FreshPalette.highlight,
      onSecondary: FreshPalette.darkPageBackground,
      tertiary: FreshPalette.highlight,
      onTertiary: FreshPalette.darkPageBackground,
      primaryContainer: FreshPalette.darkAccentSurface,
      onPrimaryContainer: FreshPalette.highlight,
      secondaryContainer: FreshPalette.darkAccentSurface,
      onSecondaryContainer: FreshPalette.darkHeading,
      surface: FreshPalette.darkPageBackground,
      onSurface: FreshPalette.darkHeading,
      onSurfaceVariant: FreshPalette.darkSecondaryText,
      outline: FreshPalette.darkOutline,
      outlineVariant: const Color(0xFF2A3830),
      surfaceBright: FreshPalette.darkCard,
      surfaceContainerLowest: const Color(0xFF0C1210),
      surfaceContainerLow: const Color(0xFF161E1A),
      surfaceContainer: const Color(0xFF19211D),
      surfaceContainerHigh: const Color(0xFF1A2320),
      surfaceContainerHighest: FreshPalette.darkCard,
      error: AppColors.statusRed,
      onError: FreshPalette.darkOnPrimary,
      errorContainer: AppColors.statusRed.withValues(alpha: 0.24),
      onErrorContainer: const Color(0xFFFFB4AB),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: FreshPalette.darkPageBackground,
      headlineColor: FreshPalette.darkHeading,
      bodyColor: FreshPalette.darkSecondaryText,
      textButtonColor: FreshPalette.highlight,
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
        iconTheme: IconThemeData(color: headlineColor),
      ),
      cardColor: colorScheme.surfaceContainerHighest,
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      dividerColor: colorScheme.outline,
      dividerTheme: DividerThemeData(color: colorScheme.outline),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
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
        titleMedium: TextStyle(
          color: headlineColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(color: bodyColor, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: bodyColor, fontSize: 14, height: 1.4),
        bodySmall: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
        labelLarge: TextStyle(
          color: headlineColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textButtonColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedItemColor: colorScheme.secondary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.8),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: headlineColor,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        contentTextStyle: TextStyle(
          color: bodyColor,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.secondary,
      ),
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.secondaryContainer,
        checkmarkColor: colorScheme.secondary,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        side: BorderSide(color: colorScheme.outline),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
    );
  }
}
