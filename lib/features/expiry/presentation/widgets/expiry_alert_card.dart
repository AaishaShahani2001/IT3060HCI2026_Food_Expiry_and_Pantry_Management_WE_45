import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../pantry/domain/models/pantry_item.dart';

class ExpiryAlertCard extends StatelessWidget {
  const ExpiryAlertCard({
    super.key,
    required this.name,
    required this.quantity,
    required this.message,
    required this.priority,
    this.category,
    required this.onUpdate,
    required this.onStopTracking,
  });

  final String name;
  final String quantity;
  final String message;
  final String priority;
  final PantryCategory? category;

  final VoidCallback onUpdate;
  final VoidCallback onStopTracking;

  Color get _accentColor {
    switch (priority.toLowerCase()) {
      case 'critical':
        return const Color(0xFFE53935);

      case 'high':
        return const Color(0xFFFF6B00);

      case 'medium':
        return const Color(0xFFF4A000);

      default:
        return AppColors.primaryGreen;
    }
  }

  Color get _backgroundColor {
    switch (priority.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFFF1F1);

      case 'high':
        return const Color(0xFFFFF6ED);

      case 'medium':
        return const Color(0xFFFFFAEA);

      default:
        return const Color(0xFFF2FAF4);
    }
  }

  String get _priorityLabel {
    switch (priority.toLowerCase()) {
      case 'critical':
        return 'CRITICAL';

      case 'high':
        return 'URGENT';

      case 'medium':
        return 'SOON';

      default:
        return 'MONITOR';
    }
  }

  IconData get _statusIcon {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.error_rounded;

      case 'high':
        return Icons.warning_rounded;

      case 'medium':
        return Icons.schedule_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left urgency indicator
              Container(width: 5, color: _accentColor),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP ROW
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product icon
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              category?.icon ?? Icons.inventory_2_outlined,
                              color: _accentColor,
                              size: 25,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Product information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF263238),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Priority badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _backgroundColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _priorityLabel,
                                        style: TextStyle(
                                          color: _accentColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  quantity,
                                  style: const TextStyle(
                                    color: Color(0xFF7A858C),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // EXPIRY STATUS
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(_statusIcon, color: _accentColor, size: 19),

                            const SizedBox(width: 9),

                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onUpdate,
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('Update'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: BorderSide(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                backgroundColor: AppColors.primaryGreen
                                    .withValues(alpha: 0.04),
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onStopTracking,
                              icon: const Icon(
                                Icons.notifications_off_outlined,
                                size: 17,
                              ),
                              label: const Text('Stop Tracking'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF667085),
                                side: BorderSide(
                                  color: const Color(0xFFD0D5DD),
                                ),
                                backgroundColor: const Color(0xFFF8F9FA),
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
