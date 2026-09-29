import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class ExpirySummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const ExpirySummaryCard({
    super.key,

    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: backgroundColor,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: color),

          const SizedBox(height: 8),

          Text(
            value,

            style: TextStyle(
              color: color,

              fontSize: 22,

              fontWeight: FontWeight.bold,
            ),
          ),

          Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
