import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Days until expiry (inclusive) that qualify as "expiring soon".
const int kExpiryExpiringSoonDays = 3;

enum ExpiryStatus {
  fresh,
  expiringSoon,
  expired,
  unknown;

  Color get color {
    switch (this) {
      case ExpiryStatus.fresh:
        return AppColors.statusFresh;
      case ExpiryStatus.expiringSoon:
        return AppColors.statusOrange;
      case ExpiryStatus.expired:
        return AppColors.statusRed;
      case ExpiryStatus.unknown:
        return AppColors.textSecondary.withValues(alpha: 0.5);
    }
  }

  String get label {
    switch (this) {
      case ExpiryStatus.fresh:
        return 'Fresh';
      case ExpiryStatus.expiringSoon:
        return 'Expiring soon';
      case ExpiryStatus.expired:
        return 'Expired';
      case ExpiryStatus.unknown:
        return 'Expiry date unknown';
    }
  }

  String get semanticLabel => 'Expiry status: $label';

  String get badgeLabel {
    switch (this) {
      case ExpiryStatus.fresh:
        return 'Fresh';
      case ExpiryStatus.expiringSoon:
        return 'Expiring Soon';
      case ExpiryStatus.expired:
        return 'Expired';
      case ExpiryStatus.unknown:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpiryStatus.fresh:
        return Icons.check_circle_outline_rounded;
      case ExpiryStatus.expiringSoon:
        return Icons.warning_amber_rounded;
      case ExpiryStatus.expired:
        return Icons.error_outline_rounded;
      case ExpiryStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ExpiryStatus.fresh:
        return AppColors.statusFreshBg;
      case ExpiryStatus.expiringSoon:
        return AppColors.statusOrangeBg;
      case ExpiryStatus.expired:
        return AppColors.statusRedBg;
      case ExpiryStatus.unknown:
        return AppColors.iconBg;
    }
  }

  Color get foregroundColor {
    switch (this) {
      case ExpiryStatus.unknown:
        return AppColors.textSecondary;
      default:
        return color;
    }
  }
}

abstract final class ExpiryStatusHelper {
  /// Calculates expiry status from an optional expiry date.
  static ExpiryStatus fromDate(
    DateTime? expiryDate, {
    DateTime? referenceDate,
    int expiringSoonDays = kExpiryExpiringSoonDays,
  }) {
    if (expiryDate == null) return ExpiryStatus.unknown;

    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysUntilExpiry = expiry.difference(today).inDays;

    if (daysUntilExpiry < 0) return ExpiryStatus.expired;
    if (daysUntilExpiry <= expiringSoonDays) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }
}
