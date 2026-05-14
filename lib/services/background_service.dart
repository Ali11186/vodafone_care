import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _notifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  await _notifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
}

Future<void> showNotification(String message) async {
  await _notifications.show(
    0, '👨‍💼 خدمة العملاء - فودافون', message,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'vodafone_chat', 'Vodafone Chat',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

Future<void> initBackgroundService() async {
  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'vodafone_chat',
      initialNotificationTitle: 'Vodafone Care',
      initialNotificationContent: 'المحادثة شغالة في الخلفية',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  await initNotifications();
  service.on('stopService').listen((_) => service.stopSelf());
  service.on('newMessage').listen((event) async {
    if (event?['message'] != null) await showNotification(event!['message']);
  });
}

void startBackgroundService() => FlutterBackgroundService().startService();
void stopBackgroundService() => FlutterBackgroundService().invoke('stopService');
void notifyBackground(String msg) => FlutterBackgroundService().invoke('newMessage', {'message': msg});
