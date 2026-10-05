import 'browser_notification_api.dart';

BrowserNotificationApi createBrowserNotificationApi() =>
    _UnavailableNotifications();

class _UnavailableNotifications implements BrowserNotificationApi {
  @override
  BrowserNotificationPermission get permission =>
      BrowserNotificationPermission.unavailable;

  @override
  Future<BrowserNotificationPermission> requestPermission() async => permission;

  @override
  Future<bool> show({
    required String title,
    required String body,
    required String tag,
    void Function()? onClick,
  }) async => false;
}
