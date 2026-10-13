import '../../../core/constants/app_strings.dart';
import '../models/onboarding_item.dart';

abstract final class OnboardingData {
  static const List<OnboardingItem> items = [
    OnboardingItem(
      title: AppStrings.onboardingTitle1,
      description: AppStrings.onboardingDescription1,
      imagePath: 'assets/images/onboarding1.png',
    ),
    OnboardingItem(
      title: AppStrings.onboardingTitle2,
      description: AppStrings.onboardingDescription2,
      imagePath: 'assets/images/onboarding2.png',
    ),
    OnboardingItem(
      title: AppStrings.onboardingTitle3,
      description: AppStrings.onboardingDescription3,
      imagePath: 'assets/images/onboarding3.png',
    ),
  ];
}
