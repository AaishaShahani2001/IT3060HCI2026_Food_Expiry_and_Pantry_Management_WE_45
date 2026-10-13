enum BrowserNotificationPermission {
  unavailable,
  notRequested,
  denied,
  granted,
}

abstract interface class BrowserNotificationApi {
  BrowserNotificationPermission get permission;

  /// Call directly from a button handler to preserve the browser user gesture.
  Future<BrowserNotificationPermission> requestPermission();

  Future<bool> show({
    required String title,
    required String body,
    required String tag,
    void Function()? onClick,
  });
}
