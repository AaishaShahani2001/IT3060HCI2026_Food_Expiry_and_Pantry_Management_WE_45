import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/app.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';

void main() {
  testWidgets('Splash screen shows app name and navigates to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FreshTrackApp()));

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.tagline), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.onboardingTitle1), findsOneWidget);
  });
}
