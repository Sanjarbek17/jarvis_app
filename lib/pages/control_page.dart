import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widget_previews.dart';

import '../services/log_service.dart';
import '../services/remote_control_client.dart';

import '../widgets/app_header.dart';
import '../widgets/control_panel.dart';

import '../utils/platform_util.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with WidgetsBindingObserver {
  bool _isAccessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    logger.log("App initialized");
    _initSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  Future<void> _initSystem() async {
    await _checkAccessibility();
    if (!_isAccessibilityEnabled) {
      await PlatformUtil.openAccessibilitySettings();
    }
    if (!kIsWeb) {
      await PlatformUtil.requestScreenCapturePermission();
      remoteControlClient.connect();
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await PlatformUtil.isAccessibilityServiceEnabled();
    if (mounted) setState(() => _isAccessibilityEnabled = enabled);
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
              Color(0xFF1E293B), // Sleek slate-800
              Color(0xFF0F172A), // Dark slate-900
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: remoteControlClient.isConnected,
                builder: (context, isConnected, child) {
                  return AppHeader(
                    isAccessibilityEnabled: _isAccessibilityEnabled,
                    isRemoteConnected: isConnected,
                    onRequestAccessibility: PlatformUtil.openAccessibilitySettings,
                    onRequestRemote: kIsWeb ? () {} : remoteControlClient.connect,
                  );
                },
              ),
              const Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ControlPanel(),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- FLUTTER WIDGET PREVIEW ---
@Preview(name: 'Full Control Page Preview')
Widget previewControlPage() {
  return const ControlPage();
}
