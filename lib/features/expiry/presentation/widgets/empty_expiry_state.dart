import 'package:flutter/material.dart';

class EmptyExpiryState extends StatelessWidget {
  final String message;

  const EmptyExpiryState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, size: 50, color: Colors.green),

          const SizedBox(height: 10),

          Text(message),
        ],
      ),
    );
  }
}
