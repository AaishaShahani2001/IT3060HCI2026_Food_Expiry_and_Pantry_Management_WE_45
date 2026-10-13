import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/screens/expiry_notification_settings_screen.dart';
import 'package:food_expiry_and_pantry_management/core/notifications/browser_notification_service.dart';

class _FakeBrowserNotifications implements BrowserNotificationApi {
  _FakeBrowserNotifications(this.result);
  final BrowserNotificationPermission result;
  @override
  BrowserNotificationPermission permission =
      BrowserNotificationPermission.notRequested;
  int requests = 0;
  final List<String> titles = [];

  @override
  Future<BrowserNotificationPermission> requestPermission() {
    requests++;
    permission = result;
    return Future.value(permission);
  }

  @override
  Future<bool> show({
    required String title,
    required String body,
    required String tag,
    void Function()? onClick,
  }) async {
    titles.add(title);
    return permission == BrowserNotificationPermission.granted;
  }
}

void main() {
  for (final permission in [
    BrowserNotificationPermission.granted,
    BrowserNotificationPermission.denied,
  ]) {
    testWidgets('browser permission button handles ${permission.name}', (
      tester,
    ) async {
      final browser = _FakeBrowserNotifications(permission);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserNotificationServiceProvider.overrideWithValue(browser),
          ],
          child: const MaterialApp(home: ExpiryNotificationSettingsScreen()),
        ),
      );
      await tester.tap(find.text('Enable browser pop-ups'));
      await tester.pumpAndSettle();
      expect(browser.requests, 1);
      if (permission == BrowserNotificationPermission.granted) {
        expect(browser.titles, ['Expiry pop-ups enabled']);
        expect(find.text('Send test pop-up'), findsOneWidget);
      } else {
        expect(browser.titles, isEmpty);
        expect(
          find.textContaining('Notifications are blocked.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'notification list controls use a Material surface in ${brightness.name} mode',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                useMaterial3: true,
                colorSchemeSeed: Colors.green,
              ),
              home: const ExpiryNotificationSettingsScreen(),
            ),
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
