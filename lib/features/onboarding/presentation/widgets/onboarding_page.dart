import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/onboarding_item.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.item});

  final OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                return Center(
                  child: Image.asset(
                    item.imagePath,
                    width: side,
                    height: side,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              height: 1.45,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
