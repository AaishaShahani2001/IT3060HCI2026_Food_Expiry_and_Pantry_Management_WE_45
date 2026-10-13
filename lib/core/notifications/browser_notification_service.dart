import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_notification_api.dart';
import 'browser_notification_stub.dart'
    if (dart.library.js_interop) 'browser_notification_web.dart'
    as platform;

export 'browser_notification_api.dart';

final browserNotificationServiceProvider = Provider<BrowserNotificationApi>(
  (ref) => platform.createBrowserNotificationApi(),
);
