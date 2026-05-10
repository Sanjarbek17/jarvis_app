import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/wake_word_service.dart';
import '../services/qwen_ai_service.dart';
import '../services/log_service.dart';

import '../widgets/app_header.dart';
import '../widgets/transcription_area.dart';
import '../widgets/control_panel.dart';
import '../widgets/debug_log.dart';

import '../utils/platform_util.dart';
import '../utils/command_orchestrator.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isAccessibilityEnabled = false;
  bool _isModelReady = false;
  String _lastWords = 'Say \'Jarvis\' to activate...';
  String _aiStatus = 'Always listening...';
  WakeState _wakeState = WakeState.idle;
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    logger.log("App initialized");
    _initSystem();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _scrollController.dispose();
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
    
    setState(() => _isModelReady = true);
    await QwenAIService.initialize();

    final micPermission = await Permission.microphone.request();
    if (micPermission.isGranted) {
      await wakeWordService.init();
      wakeWordService.onStateChange = (state) {
        if (!mounted) return;
        setState(() {
          _wakeState = state;
          if (state == WakeState.idle) {
            _aiStatus = 'Always listening...';
            _lastWords = 'Say \'Jarvis\' to activate';
          } else if (state == WakeState.awake) {
            _aiStatus = 'Listening for command...';
            _lastWords = 'Speak your command now';
          } else if (state == WakeState.processing) {
            _aiStatus = 'AI Thinking...';
          }
        });
        if (state == WakeState.idle) _pulseController.stop();
        else _pulseController.repeat(reverse: true);
      };

      wakeWordService.onCommandDetected = (command) {
        if (!mounted) return;
        setState(() => _lastWords = command);
        _handleCommand(command);
      };

      await wakeWordService.startAlwaysOn();
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await PlatformUtil.isAccessibilityServiceEnabled();
    if (mounted) setState(() => _isAccessibilityEnabled = enabled);
  }

  void _handleCommand(String command) {
    CommandOrchestrator.processCommand(
      words: command,
      onStatusUpdate: (status) {
        if (mounted) setState(() => _aiStatus = status);
      },
      onFinish: () {
        // Any additional logic after command completion
      },
    );
  }

  void _toggleListening() {
    if (_wakeState == WakeState.processing) return;
    wakeWordService.onStateChange?.call(WakeState.awake);
    wakeWordService.resumeListening();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              isAccessibilityEnabled: _isAccessibilityEnabled,
              onRequestAccessibility: PlatformUtil.openAccessibilitySettings,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    if (_isModelReady) ...[
                      TranscriptionArea(
                        pulseAnimation: _pulseController,
                        wakeState: _wakeState,
                        lastWords: _lastWords,
                        aiStatus: _aiStatus,
                        onToggleMic: _toggleListening,
                      ),
                      const SizedBox(height: 24),
                      const ControlPanel(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              height: 220, 
              margin: const EdgeInsets.all(12),
              child: DebugLog(scrollController: _scrollController),
            ),
          ],
        ),
      ),
    );
  }
}
