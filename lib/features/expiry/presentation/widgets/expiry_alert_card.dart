import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class ExpiryAlertCard extends StatelessWidget {
  final String name;
  final String quantity;
  final String message;
  final String priority;

  final VoidCallback onUpdate;
  final VoidCallback onStopTracking;

  const ExpiryAlertCard({
    super.key,

    required this.name,
    required this.quantity,
    required this.message,
    required this.priority,

    required this.onUpdate,
    required this.onStopTracking,
  });

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (priority) {
      case "critical":
        color = AppColors.statusRed;
        break;

      case "high":
        color = AppColors.statusOrange;
        break;

      default:
        color = AppColors.statusAmber;
    }

    return Container(
      padding: const EdgeInsets.all(15),

      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),

      child: Row(
        children: [
          Icon(Icons.warning_amber, color: color),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),

                Text(quantity),

                const SizedBox(height: 5),

                Text(
                  message,

                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),

                Row(
                  children: [
                    TextButton(
                      onPressed: onUpdate,

                      child: const Text("Update"),
                    ),

                    TextButton(
                      onPressed: onStopTracking,

                      child: const Text("Stop Tracking"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
