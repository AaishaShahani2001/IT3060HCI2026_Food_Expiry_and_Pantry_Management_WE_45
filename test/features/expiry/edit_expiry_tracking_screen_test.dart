 import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/domain/repositories/expiry_repository.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/screens/edit_expiry_tracking_screen.dart';

void main() {
  testWidgets('expiry tracking edit lets the user choose an expiry time', (
    tester,
  ) async {
    final expiryDate = DateTime(2030, 4, 7, 17, 25);
    final alert = ExpiryAlert(
      id: 'user_item',
      userId: 'user',
      itemId: 'item',
      itemName: 'Milk',
      expiryDate: expiryDate,
      daysUntilExpiry: 10,
      status: 'active',
      priority: 'medium',
      message: 'Milk expiry reminder',
      isRead: false,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: EditExpiryTrackingScreen(alert: alert),
      ),
    );

    final localizations = MaterialLocalizations.of(
      tester.element(find.text('Expiry time')),
    );
    expect(
      find.text(
        localizations.formatTimeOfDay(
          TimeOfDay.fromDateTime(expiryDate),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
            tester.element(find.text('Expiry time')),
          ),
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Expiry time'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
