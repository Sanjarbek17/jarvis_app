import 'dart:async';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'log_service.dart';
import 'tts_service.dart';
import 'dart:math';

/// Always-on voice detection service.
///
/// Flow:  [IDLE] → hears wake word → [COMMAND] → hears command → callback → [IDLE]
///
/// The STT engine stops after a silence period, so we automatically restart it
/// after every session ends so it's truly always listening.

enum WakeState { idle, awake, processing }

class WakeWordService {
  static final WakeWordService _instance = WakeWordService._internal();
  factory WakeWordService() => _instance;
  WakeWordService._internal();

  // ── Configuration ──────────────────────────────────────────────────────────
  // Wake word: "Jarvis" (like Iron Man) — easy for Uzbek speakers, STT picks it up reliably.
  static const String wakeWord   = 'jarvis';
  static const Duration commandListenTimeout = Duration(seconds: 6);

  static const _platform = MethodChannel('com.example.controller_phone/voice_control');

  final List<String> _greetings = [
    "Yes?",
    "Listening",
    "Ready",
    "At your service",
    "How can I help?",
    "Yes, sir?"
  ];
  final _random = Random();

  // ── State ──────────────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable   = false;
  bool _running       = false;
  bool _isStarting    = false; // Lock to prevent redundant calls
  WakeState _state    = WakeState.idle;
  Timer? _commandTimer;
  Timer? _restartTimer;

  // Callbacks set by the UI
  void Function(WakeState)? onStateChange;
  void Function(String)?    onCommandDetected;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<bool> init() async {
    await ttsService.init();
    _isAvailable = await _speech.initialize(
      onStatus: _onStatus,
      onError: (error) {
        // 'error_no_match' is just silence/no speech heard. We log it quietly.
        if (error.errorMsg == 'error_no_match') {
          // logger.log('WakeWord: Silence...'); // Optional: log silence or just ignore
        } else {
          logger.log('WakeWord STT error: ${error.errorMsg}');
        }

        // Ensure we restart if the engine stopped, even for non-permanent errors
        if (_running && !_speech.isListening && !_isStarting) {
          _restartTimer?.cancel();
          _restartTimer = Timer(const Duration(milliseconds: 800), () {
            if (_running && !_speech.isListening && !_isStarting) {
              _state == WakeState.awake
                  ? _listenForCommand()
                  : _listenForWakeWord();
            }
          });
        }
      },
    );
    logger.log('WakeWordService init: ${_isAvailable ? 'OK' : 'FAILED'}');
    if (!_isAvailable) {
      ttsService.speak("Voice detection failed to initialize. Please check permissions.");
    }
    return _isAvailable;
  }

  // ── Public API ─────────────────────────────────────────────────────────────
  Future<void> startAlwaysOn() async {
    if (!_isAvailable || _running) return;
    _running = true;
    logger.log('WakeWord: Always-on started. Say "$wakeWord" to activate.');
    _listenForWakeWord();
  }

  Future<void> stop() async {
    _running = false;
    _commandTimer?.cancel();
    _restartTimer?.cancel();
    await _speech.stop();
    _setState(WakeState.idle);
    logger.log('WakeWord: Stopped.');
  }

  WakeState get state => _state;

  // ── Internal ───────────────────────────────────────────────────────────────
  void _setState(WakeState s) {
    _state = s;
    onStateChange?.call(s);
  }

  void _onStatus(String status) {
    // When STT goes idle/notListening, restart automatically so we're always on
    if ((status == 'notListening' || status == 'done') && _running) {
      // Small delay to let the engine settle before restarting
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(milliseconds: 800), () {
        // Only restart if we are still running, not already listening, 
        // and not in the middle of a manual transition.
        if (_running && !_speech.isListening && !_isStarting) {
          if (_state == WakeState.idle) {
            _listenForWakeWord();
          } else if (_state == WakeState.awake) {
            _listenForCommand();
          }
        }
      });
    }
  }

  Future<void> _listenForWakeWord() async {
    if (!_running || _isStarting) return;
    if (_speech.isListening) return;

    _isStarting = true;
    _setState(WakeState.idle);

    try {
      await _speech.listen(
        onResult: (result) {
          if (!result.finalResult) return;
          if (_state != WakeState.idle) return; // already activated, ignore
          final words = result.recognizedWords.toLowerCase().trim();
          logger.log('WakeWord heard: "$words"');
          if (words.contains(wakeWord)) {
            _onWakeWordDetected(words);
          }
        },
        listenFor:    const Duration(seconds: 30),
        pauseFor:     const Duration(seconds: 3),
        localeId:     'en_US',
        cancelOnError: false,
      );
    } catch (e) {
      logger.log('WakeWord listen error: $e');
    } finally {
      _isStarting = false;
    }
  }

  void _onWakeWordDetected(String fullPhrase) async {
    if (_state != WakeState.idle) return; // debounce: ignore if already active
    logger.log('WakeWord: ACTIVATED!');
    
    _isStarting = true; // Lock to prevent _onStatus from restarting prematurely
    _setState(WakeState.awake);
    
    await _speech.cancel(); // More aggressive than stop()
    _playActivationSound();
    
    // Voice acknowledgment - WAIT for it to finish
    final greeting = _greetings[_random.nextInt(_greetings.length)];
    await ttsService.speak(greeting);

    // Check if command is already in the same phrase: "jarvis go home"
    final afterWake = fullPhrase
        .replaceAll(wakeWord, '')
        .replaceAll(RegExp(r'[,.]'), '')
        .trim();

    _isStarting = false; // Release lock

    if (afterWake.length > 2) {
      logger.log('WakeWord: Inline command detected: "$afterWake"');
      Future.delayed(const Duration(milliseconds: 300), () => _dispatchCommand(afterWake));
    } else {
      // Jarvis finished speaking, now we can safely start listening for command
      _listenForCommand();
    }
  }

  Future<void> _listenForCommand() async {
    if (!_running || _isStarting) return;
    if (_speech.isListening) {
      await _speech.cancel();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isStarting = true;
    logger.log('WakeWord: Listening for command...');
    _setState(WakeState.awake);

    // Safety timeout if no command arrives
    _commandTimer?.cancel();
    _commandTimer = Timer(commandListenTimeout, () {
      if (_state == WakeState.awake) {
        logger.log('WakeWord: No command heard, going back to idle.');
        _listenForWakeWord();
      }
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!result.finalResult) return;
          final cmd = result.recognizedWords.trim();
          if (cmd.isNotEmpty) {
            _commandTimer?.cancel();
            _dispatchCommand(cmd);
          }
        },
        listenFor:    commandListenTimeout,
        pauseFor:     const Duration(seconds: 2),
        localeId:     'en_US',
        cancelOnError: false,
      );
    } catch (e) {
      logger.log('Command listen error: $e');
    } finally {
      _isStarting = false;
    }
  }

  void _dispatchCommand(String command) {
    logger.log('WakeWord: Command → "$command"');
    _setState(WakeState.processing);
    onCommandDetected?.call(command);
    // After processing, go back to idle listening
    // The caller is responsible for calling _listenForWakeWord() when done.
  }

  Future<void> _playActivationSound() async {
    try {
      HapticFeedback.mediumImpact();
      await _platform.invokeMethod('playActivationSound');
    } catch (_) {}
  }

  /// Call this after the command has been fully processed to resume wake-listening.
  void resumeListening() {
    if (_running) {
      _isStarting = true; // Block _onStatus from racing
      _speech.stop().then((_) {
        _isStarting = false;
        Future.delayed(const Duration(milliseconds: 400), _listenForWakeWord);
      });
    }
  }
}

final wakeWordService = WakeWordService();
