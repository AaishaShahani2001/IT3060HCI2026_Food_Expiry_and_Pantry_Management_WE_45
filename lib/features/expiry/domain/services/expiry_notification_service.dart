import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class ExpiryNotificationService {


final FlutterLocalNotificationsPlugin plugin;


ExpiryNotificationService(
this.plugin
);



Future<void> showExpiryNotification({

required String title,

required String body,

}) async {


const details =
NotificationDetails(

android:
AndroidNotificationDetails(

'expiry_channel',

'Expiry Alerts',

channelDescription:
'Food expiry reminders',

importance:
Importance.high,

priority:
Priority.high,

),


);



await plugin.show(

DateTime.now()
.millisecondsSinceEpoch,

title,

body,

details,

);


}


}