import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_section_header.dart';

void main() {
  testWidgets('HomeSectionHeader renders asset image icon and title', (
    tester,
  ) async {
    bool seeAllTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeSectionHeader(
            title: 'Expiry Soon',
            assetPath: 'assets/images/expiry_soon.png',
            onSeeAll: () => seeAllTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Expiry Soon'), findsOneWidget);
    expect(find.text('See All'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('See All'));
    expect(seeAllTapped, isTrue);
  });

  testWidgets(
    'HomeSectionHeader supports pulse animation when animateIcon is true',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TickerMode(
            enabled: true,
            child: const Scaffold(
              body: HomeSectionHeader(
                title: 'Expiry Soon',
                assetPath: 'assets/images/expiry_soon.png',
                animateIcon: true,
              ),
            ),
          ),
        ),
      );

      final headerFinder = find.byType(HomeSectionHeader);
      expect(
        find.descendant(
          of: headerFinder,
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: headerFinder,
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'HomeSectionHeader respects disableAnimations by keeping icon static',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: HomeSectionHeader(
                title: 'Expiry Soon',
                assetPath: 'assets/images/expiry_soon.png',
                animateIcon: true,
              ),
            ),
          ),
        ),
      );

      final headerFinder = find.byType(HomeSectionHeader);
      expect(
        find.descendant(
          of: headerFinder,
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: headerFinder,
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HomeSectionHeader fallback icon shows on asset load error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: HomeSectionHeader(
            title: 'Test Header',
            assetPath: 'assets/images/non_existent.png',
            fallbackIcon: Icons.schedule_outlined,
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
