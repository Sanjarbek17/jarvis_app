import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/wake_word_service.dart';
import 'services/qwen_ai_service.dart';
import 'services/screen_reader_service.dart';
import 'services/action_executor_service.dart';
import 'services/log_service.dart';

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

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Platform channel kept only for accessibility check + settings shortcut
  static const _platform = MethodChannel('com.example.controller_phone/voice_control');

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
    _checkModelAndPermissions();
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
    logger.log("App state: ${state.name}");
    if (state == AppLifecycleState.resumed) {
      _checkModelAndPermissions();
    }
  }

  Future<void> _checkModelAndPermissions() async {
    try {
      final enabled = await _platform.invokeMethod<bool>('isAccessibilityServiceEnabled');
      setState(() => _isAccessibilityEnabled = enabled ?? false);
      logger.log("Accessibility: ${_isAccessibilityEnabled ? 'Enabled' : 'Disabled'}");
    } catch (e) {
      logger.log("Error checking accessibility: $e");
    }

    setState(() => _isModelReady = true);
    await QwenAIService.initialize();

    // Request mic and start always-on wake word detection
    final micPermission = await Permission.microphone.request();
    if (micPermission.isGranted) {
      await wakeWordService.init();
      wakeWordService.onStateChange = (state) {
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
        setState(() => _lastWords = command);
        _processCommand(command);
      };
      await wakeWordService.startAlwaysOn();
    } else {
      logger.log('Mic permission denied');
    }
  }

  Future<void> _requestAccessibility() async {
    logger.log('Opening accessibility settings...');
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      logger.log('Failed to open settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Removed: _downloadModel, _pickLocalModel, _clearCustomModel
  // AI now runs on Mac via Ollama — no local model management needed.


  /// Manual mic button — tap to speak without saying the wake word.
  Future<void> _toggleListening() async {
    if (_wakeState == WakeState.processing) return;
    if (_wakeState == WakeState.awake) {
      wakeWordService.resumeListening();
    } else {
      logger.log('Manual activate');
      wakeWordService.onStateChange?.call(WakeState.awake);
      wakeWordService.resumeListening(); // trigger listen for command
    }
  }

  /// Orchestrates: read screen → AI inference → execute action.
  Future<void> _processCommand(String words) async {
    setState(() => _aiStatus = 'Reading screen...');

    // 1. Capture current screen context
    final screenContent = await screenReaderService.getScreenContent();
    if (screenContent.isNotEmpty) {
      logger.log('Screen: ${screenContent.substring(0, screenContent.length.clamp(0, 120))}...');
    }

    // 2. Ask AI (with screen context for smarter decisions)
    setState(() => _aiStatus = 'AI Thinking...');
    final action = await QwenAIService.getAction(words, screenContent: screenContent);

    // 3. Execute the action
    setState(() => _aiStatus = "Executing: ${action['action']}");
    final resultMsg = await actionExecutorService.execute(action);
    setState(() => _aiStatus = resultMsg);

    // 4. Resume always-on listening
    await Future.delayed(const Duration(milliseconds: 500));
    wakeWordService.resumeListening();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    if (!_isModelReady) _buildModelDownload(),
                    if (_isModelReady) ...[
                      _buildTranscriptionArea(),
                      const SizedBox(height: 24),
                      _buildControlPanel(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Floating Debug Log at bottom
            Container(
              height: 220, 
              margin: const EdgeInsets.all(12),
              child: _buildDebugLog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHONE CONTROLLER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.blue.shade400,
                ),
              ),
              const Text(
                'Voice Assistant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          _buildStatusIndicatorWidget(),
        ],
      ),
    );
  }

  // No longer used — _isModelReady is always true with Ollama approach.
  Widget _buildModelDownload() => const SizedBox.shrink();

  Widget _buildDebugLog() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black, // Darker for high contrast
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2), // Clearer border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DEBUG LOG',
                style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                onPressed: () => logger.clear(),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: logger.logs,
              builder: (context, logs, child) {
                // Auto scroll to bottom on new logs
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicatorWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isAccessibilityEnabled ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isAccessibilityEnabled ? Colors.green.shade400 : Colors.red.shade400,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isAccessibilityEnabled ? Icons.check_circle : Icons.warning,
                size: 14,
                color: _isAccessibilityEnabled ? Colors.green.shade400 : Colors.red.shade400,
              ),
              const SizedBox(width: 6),
              const Text(
                'Access',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!_isAccessibilityEnabled)
          GestureDetector(
            onTap: _requestAccessibility,
            child: const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text('ENABLE NOW', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildTranscriptionArea() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  if (_wakeState != WakeState.idle)
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20 * _pulseController.value,
                      spreadRadius: 10 * _pulseController.value,
                    ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _toggleListening,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor: _wakeState != WakeState.idle
                      ? Colors.blue.shade600
                      : Colors.white10,
                  foregroundColor: Colors.white,
                ),
                child: Icon(
                  _wakeState != WakeState.idle ? Icons.mic : Icons.mic_none,
                  size: 30,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        Text(
          _lastWords,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Status: $_aiStatus',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade300,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text(
            'DIRECT CONTROLS',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSmallControl(Icons.arrow_back, 'BACK',    () => actionExecutorService.execute({'action': 'back'})),
              _buildSmallControl(Icons.home,        'HOME',    () => actionExecutorService.execute({'action': 'home'})),
              _buildSmallControl(Icons.layers,      'RECENTS', () => actionExecutorService.execute({'action': 'recents'})),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          const Text(
            'AI SERVER',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.computer, color: Colors.blue),
            title: const Text('Ollama on Mac (LAN)', style: TextStyle(fontSize: 14, color: Colors.white)),
            subtitle: Text(
              'qwen2.5:0.5b @ ${QwenAIService.macIp}:11434',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade300),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () async {
                await QwenAIService.initialize();
              },
              tooltip: 'Re-check connection',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallControl(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}
