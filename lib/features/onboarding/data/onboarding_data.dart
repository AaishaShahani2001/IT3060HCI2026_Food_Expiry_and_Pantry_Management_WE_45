import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../models/onboarding_item.dart';

abstract final class OnboardingData {
  static const List<OnboardingItem> items = [
    OnboardingItem(
      title: AppStrings.onboardingTitle1,
      description: AppStrings.onboardingDescription1,
      icon: Icons.event_available_rounded,
    ),
    OnboardingItem(
      title: AppStrings.onboardingTitle2,
      description: AppStrings.onboardingDescription2,
      icon: Icons.kitchen_rounded,
    ),
    OnboardingItem(
      title: AppStrings.onboardingTitle3,
      description: AppStrings.onboardingDescription3,
      icon: Icons.eco_rounded,
    ),
  ];
}
