import 'dart:js_interop';

import 'browser_notification_api.dart';

@JS('Notification')
external JSFunction? get _notificationConstructor;

@JS('isSecureContext')
external bool get _isSecureContext;

@JS('window.focus')
external void _focusWindow();

@JS('Notification')
extension type _BrowserNotification._(JSObject _) implements JSObject {
  external factory _BrowserNotification(
    String title,
    _NotificationOptions options,
  );
  external static String get permission;
  external static JSPromise<JSString> requestPermission();
  external set onclick(JSFunction callback);
  external void close();
}

extension type _NotificationOptions._(JSObject _) implements JSObject {
  external factory _NotificationOptions({
    required String body,
    required String tag,
    required String icon,
  });
}

BrowserNotificationApi createBrowserNotificationApi() => _WebNotifications();

class _WebNotifications implements BrowserNotificationApi {
  @override
  BrowserNotificationPermission get permission {
    if (_notificationConstructor == null || !_isSecureContext) {
      return BrowserNotificationPermission.unavailable;
    }
    return switch (_BrowserNotification.permission) {
      'granted' => BrowserNotificationPermission.granted,
      'denied' => BrowserNotificationPermission.denied,
      _ => BrowserNotificationPermission.notRequested,
    };
  }

  @override
  Future<BrowserNotificationPermission> requestPermission() {
    if (permission != BrowserNotificationPermission.notRequested) {
      return Future.value(permission);
    }
    // Invoke synchronously, before any await can lose browser user activation.
    return _BrowserNotification.requestPermission().toDart.then(
      (_) => permission,
    );
  }

  @override
  Future<bool> show({
    required String title,
    required String body,
    required String tag,
    void Function()? onClick,
  }) async {
    if (permission != BrowserNotificationPermission.granted) return false;
    try {
      final notification = _BrowserNotification(
        title,
        _NotificationOptions(body: body, tag: tag, icon: 'icons/Icon-192.png'),
      );
      notification.onclick = ((JSAny? event) {
        _focusWindow();
        notification.close();
        onClick?.call();
      }).toJS;
      return true;
    } catch (_) {
      return false;
    }
  }
}
