import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/welcome_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('food-storage.avif can be decoded by this Flutter engine', () async {
    final bytes = await rootBundle.load('assets/images/food-storage.avif');
    final codec = await instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(0));
    expect(frame.image.height, greaterThan(0));
  });

  testWidgets('Welcome card keeps copy and does not overflow at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: WelcomeSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.homeWelcome), findsOneWidget);
    expect(find.text(AppStrings.homeWelcomeMessage), findsOneWidget);
    expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
