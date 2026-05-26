import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pages/control_page.dart';
import 'services/wake_word_service.dart';
import 'services/qwen_ai_service.dart';
import 'utils/command_orchestrator.dart';
import 'services/remote_control_client.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'voice_control_channel',
    'Voice Control Service',
    description: 'This channel is used for background voice listening.',
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
      notificationChannelId: 'voice_control_channel',
      initialNotificationTitle: 'Jarvis',
      initialNotificationContent: 'Waiting for wake word...',
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
    wakeWordService.stop();
    remoteControlClient.disconnect();
    service.stopSelf();
  });

  await QwenAIService.initialize();

  wakeWordService.onCommandDetected = (command) {
    CommandOrchestrator.processCommand(
      words: command,
      onStatusUpdate: (status) {
        service.invoke('update', {'status': status});
      },
      onFinish: () {},
    );
  };

  // Start listening continuously in background
  await wakeWordService.init();
  await wakeWordService.startAlwaysOn();
  
  // Connect to the remote control websocket server
  remoteControlClient.connect();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request necessary permissions for background execution
  await Permission.microphone.request();
  await Permission.notification.request();
  
  await initializeService();
  runApp(const VoiceControllerApp());
}

class VoiceControllerApp extends StatelessWidget {
  const VoiceControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Phone Controller',
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
