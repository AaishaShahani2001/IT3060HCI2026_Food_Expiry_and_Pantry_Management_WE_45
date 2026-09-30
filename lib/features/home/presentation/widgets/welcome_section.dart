import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';

class WelcomeSection extends StatefulWidget {
  const WelcomeSection({super.key});

  static const _backgroundImage = AssetImage('assets/images/food-storage.avif');
  static const _cardRadius = BorderRadius.all(Radius.circular(20));
  static const _contentPadding = EdgeInsets.all(20);

  @override
  State<WelcomeSection> createState() => _WelcomeSectionState();
}

class _WelcomeSectionState extends State<WelcomeSection> {
  bool _imageFailed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usePhoto = !_imageFailed;
    // Near-white on the photo overlay; original theme colours if AVIF fails.
    final titleColor = usePhoto
        ? FreshPalette.darkOnPrimary
        : colorScheme.onSurface;
    final messageColor = usePhoto
        ? FreshPalette.darkOnPrimary.withValues(alpha: 0.92)
        : colorScheme.onSurfaceVariant;
    final iconWellColor = usePhoto
        ? FreshPalette.darkOnPrimary.withValues(alpha: 0.18)
        : colorScheme.surfaceContainerHighest;
    final iconColor = usePhoto
        ? FreshPalette.darkOnPrimary
        : colorScheme.primary;
    final overlay = Color(0xFF0E2F25).withValues(alpha: isDark ? 0.62 : 0.55);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: usePhoto ? null : colorScheme.secondaryContainer,
        borderRadius: WelcomeSection._cardRadius,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: WelcomeSection._cardRadius,
        child: Stack(
          children: [
            // Layer a blurred food-storage image and contrast overlay behind
            // the Welcome content to keep the text readable.
            if (usePhoto)
              Positioned.fill(
                child: Image(
                  image: WelcomeSection._backgroundImage,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame == null && !wasSynchronouslyLoaded) {
                          return ColoredBox(
                            color: colorScheme.secondaryContainer,
                          );
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 3,
                                sigmaY: 3,
                              ),
                              child: child,
                            ),
                            ColoredBox(color: overlay),
                          ],
                        );
                      },
                  errorBuilder: (context, error, stackTrace) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_imageFailed) {
                        setState(() => _imageFailed = true);
                      }
                    });
                    return ColoredBox(color: colorScheme.secondaryContainer);
                  },
                ),
              ),
            Padding(
              padding: WelcomeSection._contentPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.homeWelcome,
                          style: textTheme.headlineMedium?.copyWith(
                            color: titleColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.homeWelcomeMessage,
                          style: textTheme.bodyLarge?.copyWith(
                            color: messageColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconWellColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.eco_rounded, size: 32, color: iconColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
