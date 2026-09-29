import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/app.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_router.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/onboarding/data/onboarding_data.dart';
import 'package:food_expiry_and_pantry_management/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  testWidgets('Splash screen shows branding and navigates to onboarding', (
    tester,
  ) async {
    appRouter.go(AppRoutes.splash);
    await tester.pumpWidget(const ProviderScope(child: FreshTrackApp()));
    await tester.pump();

    expect(
      find.image(const AssetImage('assets/images/HCI_LOGO.png')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.onboardingTitle1), findsOneWidget);
    expect(find.text(AppStrings.onboardingDescription1), findsOneWidget);
    expect(find.text(AppStrings.skip), findsOneWidget);
    expect(find.text(AppStrings.next), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/onboarding1.png')),
      findsWidgets,
    );
  });

  testWidgets('Onboarding Next reaches each page and Get Started opens login', (
    tester,
  ) async {
    await _pumpToOnboarding(tester);

    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.onboardingTitle2), findsOneWidget);
    expect(find.text(AppStrings.onboardingDescription2), findsOneWidget);

    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.onboardingTitle3), findsOneWidget);
    expect(find.text(AppStrings.onboardingDescription3), findsOneWidget);
    expect(find.text(AppStrings.skip), findsNothing);
    expect(find.text(AppStrings.getStarted), findsOneWidget);

    await tester.tap(find.text(AppStrings.getStarted));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Onboarding swipe and Skip open the existing login route', (
    tester,
  ) async {
    await _pumpToOnboarding(tester);

    expect(find.text(AppStrings.onboardingTitle1), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.onboardingTitle2), findsOneWidget);

    await tester.tap(find.text(AppStrings.skip));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Onboarding fits a compact phone in light and dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: theme, home: const OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.onboardingTitle1), findsOneWidget);
      expect(find.text(AppStrings.next), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Onboarding illustrations share the same vertical center', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final centers = <double>[];
    for (var index = 0; index < OnboardingData.items.length; index++) {
      final item = OnboardingData.items[index];
      final image = _visibleImageRect(tester, item.imagePath);
      final title = tester.getRect(find.text(item.title));
      final pageTop = tester.getTopLeft(find.byType(PageView)).dy;

      final spaceAbove = image.top - pageTop;
      final spaceBelow = title.top - image.bottom;
      expect(spaceAbove, greaterThan(24), reason: item.title);
      expect(
        (spaceAbove - spaceBelow).abs(),
        lessThan(48),
        reason: item.title,
      );

      centers.add(image.center.dy);

      if (index < OnboardingData.items.length - 1) {
        await tester.tap(find.text(AppStrings.next));
        await tester.pumpAndSettle();
      }
    }

    expect((centers[0] - centers[1]).abs(), lessThan(12));
    expect((centers[1] - centers[2]).abs(), lessThan(12));
    expect((centers[0] - centers[2]).abs(), lessThan(12));
  });

  testWidgets('Onboarding layout builds in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.onboardingTitle1), findsOneWidget);
    expect(find.text(AppStrings.skip), findsOneWidget);
    expect(find.text(AppStrings.next), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Rect _visibleImageRect(WidgetTester tester, String asset) {
  final viewWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  Rect? match;

  for (final element in find.image(AssetImage(asset)).evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.left >= -1 && rect.right <= viewWidth + 1) {
      match = rect;
    }
  }

  expect(match, isNotNull, reason: asset);
  return match!;
}

Future<void> _pumpToOnboarding(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  appRouter.go(AppRoutes.splash);
  await tester.pumpWidget(const ProviderScope(child: FreshTrackApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2500));
  await tester.pumpAndSettle();
}
