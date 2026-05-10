import 'package:flutter/material.dart';
import 'pages/control_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
