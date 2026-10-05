@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:food_expiry_and_pantry_management/core/notifications/browser_notification_api.dart';
import 'package:food_expiry_and_pantry_management/core/notifications/browser_notification_web.dart';

@JS('eval')
external JSAny? _eval(String source);

@JS('__expiryNotificationRequests')
external int get _requests;

@JS('__expiryNotifications.length')
external int get _shownCount;

void main() {
  setUp(() {
    _eval(r'''
      globalThis.__originalExpiryNotification = globalThis.Notification;
      globalThis.__expiryNotificationRequests = 0;
      globalThis.__expiryNotifications = [];
      globalThis.Notification = class {
        static permission = 'default';
        static requestPermission() {
          globalThis.__expiryNotificationRequests++;
          this.permission = 'granted';
          return Promise.resolve('granted');
        }
        constructor(title, options) {
          this.title = title;
          this.options = options;
          globalThis.__expiryNotifications.push(this);
        }
        close() {}
      };
    ''');
  });
  tearDown(() {
    _eval('globalThis.Notification = globalThis.__originalExpiryNotification;');
  });

  test(
    'permission is requested from the click before returning the future',
    () async {
      final browser = createBrowserNotificationApi();
      expect(browser.permission, BrowserNotificationPermission.notRequested);
      final request = browser.requestPermission();
      expect(_requests, 1);
      expect(await request, BrowserNotificationPermission.granted);
    },
  );

  test('sends browser popup contents and handles click navigation', () async {
    final browser = createBrowserNotificationApi();
    await browser.requestPermission();
    var clicked = false;
    expect(
      await browser.show(
        title: 'grains expires tomorrow',
        body: 'Use it soon.',
        tag: 'grains',
        onClick: () => clicked = true,
      ),
      true,
    );
    expect(_shownCount, 1);
    expect(
      (_eval('globalThis.__expiryNotifications[0].title') as JSString).toDart,
      'grains expires tomorrow',
    );
    expect(
      (_eval('globalThis.__expiryNotifications[0].options.body') as JSString)
          .toDart,
      'Use it soon.',
    );
    _eval('globalThis.__expiryNotifications[0].onclick(null)');
    expect(clicked, true);
  });

  test('denied browser permission does not create a system popup', () async {
    _eval("globalThis.Notification.permission = 'denied'");
    final browser = createBrowserNotificationApi();
    expect(
      await browser.requestPermission(),
      BrowserNotificationPermission.denied,
    );
    expect(_requests, 0);
    expect(
      await browser.show(title: 'grains', body: 'Expiring soon', tag: 'grains'),
      false,
    );
    expect(_shownCount, 0);
  });

  test('unavailable browsers fall back without throwing', () async {
    _eval('globalThis.Notification = undefined');
    final browser = createBrowserNotificationApi();
    expect(browser.permission, BrowserNotificationPermission.unavailable);
    expect(
      await browser.show(title: 'grains', body: 'Expiring soon', tag: 'grains'),
      false,
    );
  });
}
