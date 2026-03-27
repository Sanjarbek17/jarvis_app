import 'dart:async';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'log_service.dart';

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

  // ── State ──────────────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable   = false;
  bool _running       = false;
  WakeState _state    = WakeState.idle;
  Timer? _commandTimer;
  Timer? _restartTimer;

  // Callbacks set by the UI
  void Function(WakeState)? onStateChange;
  void Function(String)?    onCommandDetected;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<bool> init() async {
    _isAvailable = await _speech.initialize(
      onStatus: _onStatus,
      onError: (error) {
        logger.log('WakeWord STT error: $error');
        // permanent=true means STT engine fully stopped — restart it
        if (_running && error.permanent) {
          _restartTimer?.cancel();
          _restartTimer = Timer(const Duration(milliseconds: 600), () {
            if (_running && !_speech.isListening) {
              _state == WakeState.awake
                  ? _listenForCommand()
                  : _listenForWakeWord();
            }
          });
        }
      },
    );
    logger.log('WakeWordService init: ${_isAvailable ? 'OK' : 'FAILED'}');
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
      _restartTimer = Timer(const Duration(milliseconds: 400), () {
        if (_running && !_speech.isListening) {
          if (_state == WakeState.idle) {
            _listenForWakeWord();
          } else if (_state == WakeState.awake) {
            _listenForCommand();
          }
        }
      });
    }
  }

  void _listenForWakeWord() {
    if (!_running) return;
    _setState(WakeState.idle);
    _speech.listen(
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
  }

  void _onWakeWordDetected(String fullPhrase) {
    if (_state != WakeState.idle) return; // debounce: ignore if already active
    logger.log('WakeWord: ACTIVATED!');
    _setState(WakeState.awake);
    _speech.stop(); // stop the wake-word listener before playing sound/starting command
    _playActivationSound();

    // Check if command is already in the same phrase: "jarvis go home"
    final afterWake = fullPhrase
        .replaceAll(wakeWord, '')
        .replaceAll(RegExp(r'[,.]'), '')
        .trim();

    if (afterWake.length > 2) {
      logger.log('WakeWord: Inline command detected: "$afterWake"');
      Future.delayed(const Duration(milliseconds: 300), () => _dispatchCommand(afterWake));
    } else {
      Future.delayed(const Duration(milliseconds: 400), _listenForCommand);
    }
  }

  void _listenForCommand() {
    if (!_running) return;
    logger.log('WakeWord: Listening for command...');
    _setState(WakeState.awake);

    // Safety timeout if no command arrives
    _commandTimer?.cancel();
    _commandTimer = Timer(commandListenTimeout, () {
      if (_state == WakeState.awake) {
        logger.log('WakeWord: No command heard, going back to idle.');
        _setState(WakeState.idle);
        _listenForWakeWord();
      }
    });

    _speech.listen(
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
      _speech.stop().then((_) {
        Future.delayed(const Duration(milliseconds: 300), _listenForWakeWord);
      });
    }
  }
}

final wakeWordService = WakeWordService();
