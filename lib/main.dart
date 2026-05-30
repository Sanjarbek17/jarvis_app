import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pages/control_page.dart';
import 'services/remote_control_client.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'remote_control_channel',
    'Remote Control Service',
    description: 'This channel is used for the background remote control connection.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'remote_control_channel',
      initialNotificationTitle: 'Phone Controller',
      initialNotificationContent: 'Remote control active...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  service.on('stopService').listen((event) {
    remoteControlClient.disconnect();
    service.stopSelf();
  });
  
  // Connect to the remote control websocket server
  remoteControlClient.connect();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request necessary permissions for background execution
  await Permission.notification.request();
  
  await initializeService();
  runApp(const PhoneControllerApp());
}

class PhoneControllerApp extends StatelessWidget {
  const PhoneControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const ControlPage(),
    );
  }
}
