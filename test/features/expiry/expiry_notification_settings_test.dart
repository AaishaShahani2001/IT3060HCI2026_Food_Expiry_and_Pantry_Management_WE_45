import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/screens/expiry_notification_settings_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'notification list controls use a Material surface in ${brightness.name} mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              useMaterial3: true,
              colorSchemeSeed: Colors.green,
            ),
            home: const ExpiryNotificationSettingsScreen(),
          ),
        );

        final option = find.widgetWithText(CheckboxListTile, 'Expiring soon');
        expect(option, findsOneWidget);
        expect(
          find.ancestor(of: option, matching: find.byType(Material)),
          findsWidgets,
        );

        await tester.tap(option);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
