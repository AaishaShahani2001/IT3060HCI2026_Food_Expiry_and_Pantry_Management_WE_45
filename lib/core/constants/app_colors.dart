import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color primaryDark = Color(0xFF2E7D32);
  static const Color mediumGreen = Color(0xFF2E7D32);
  static const Color cream = Color(0xFFFBF8F1);
  static const Color softGreen = Color(0xFFE8F5E9);
  static const Color heading = Color(0xFF1B5E20);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF5F6B5A);
  static const Color indicatorInactive = Color(0xFFC8E6C9);
  static const Color unreadBadge = Color(0xFFE53935);

  // Status Urgency Colors
  static const Color statusFresh = Color(0xFF2E7D32);
  static const Color statusFreshBg = Color(0xFFE8F5E9);
  static const Color statusAmber = Color(0xFFF57C00);
  static const Color statusAmberBg = Color(0xFFFFF8E1);
  static const Color statusOrange = Color(0xFFE65100);
  static const Color statusOrangeBg = Color(0xFFFFF3E0);
  static const Color statusRed = Color(0xFFD32F2F);
  static const Color statusRedBg = Color(0xFFFFEBEE);

  // Structural & Card Styling Colors
  static const Color cardBorder = Color(0xFFE6E0D4);
  static const Color iconBg = Color(0xFFF2ECE1);
  static const Color badgeTextDark = Color(0xFF2D332D);

  // Dark theme surfaces (existing light colours above are unchanged)
  static const Color darkBackground = Color(0xFF121A16);
  static const Color darkCard = Color(0xFF1E2A24);
  static const Color darkBorder = Color(0xFF3A4A40);
  static const Color darkTextPrimary = Color(0xFFE8EEE9);
  static const Color darkTextSecondary = Color(0xFFB0BDB4);
  static const Color darkIconBg = Color(0xFF2A3830);
}

class FreshPalette {
  FreshPalette._();

  static const Color primaryButton = Color(0xFF174A3A);
  static const Color selected = Color(0xFF2E6B4E);
  static const Color highlight = Color(0xFFB8D98A);
  static const Color card = Color(0xFFFFFFFF);
  static const Color pageBackground = Color(0xFFF5F7F2);
  static const Color heading = Color(0xFF17201B);
  static const Color secondaryText = Color(0xFF6B7280);

  /// Green-grey border that sits between [pageBackground] and [heading].
  static const Color outline = Color(0xFFD5DCD4);

  /// Highlight-tinted surface for chips, icon wells, and selected rows.
  static const Color accentSurface = Color(0xFFE7F0D8);

  // Dark-theme equivalents — same green identity, lifted contrast.
  static const Color darkPageBackground = Color(0xFF101714);
  static const Color darkCard = Color(0xFF1C2621);
  static const Color darkHeading = Color(0xFFF3F6F4);
  static const Color darkSecondaryText = Color(0xFFB4BCC0);
  static const Color darkOutline = Color(0xFF3D4C44);
  static const Color darkAccentSurface = Color(0xFF24352C);
  static const Color darkOnPrimary = Color(0xFFF4F7F5);
}
