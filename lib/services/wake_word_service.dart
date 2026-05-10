import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'log_service.dart';
import 'tts_service.dart';
import 'stt_service.dart';
import 'dart:math';

/// Hybrid voice detection service.
/// 1. Uses 'speech_to_text' for efficient wake-word listening.
/// 2. Uses 'record' + 'SttService' (Whisper) for high-accuracy command transcription.
enum WakeState { idle, awake, processing }

class WakeWordService {
  static final WakeWordService _instance = WakeWordService._internal();
  factory WakeWordService() => _instance;
  WakeWordService._internal();

  // ── Configuration ──────────────────────────────────────────────────────────
  static const String wakeWord = 'jarvis';
  static const Duration commandMaxDuration = Duration(seconds: 7);
  static const Duration silenceDuration = Duration(milliseconds: 1500);

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
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isAvailable = false;
  bool _running = false;
  bool _isStarting = false; 
  WakeState _state = WakeState.idle;
  
  Timer? _silenceTimer;
  Timer? _maxDurationTimer;
  Timer? _restartTimer;

  // Callbacks set by the UI
  void Function(WakeState)? onStateChange;
  void Function(String)? onCommandDetected;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<bool> init() async {
    await ttsService.init();
    await SttService.initialize();
    
    _isAvailable = await _speech.initialize(
      onStatus: _onStatus,
      onError: (error) {
        if (error.errorMsg != 'error_no_match') {
          logger.log('WakeWord STT error: ${error.errorMsg}');
        }
        _handleEngineStop();
      },
    );
    
    logger.log('WakeWordService init: ${_isAvailable ? 'OK' : 'FAILED'}');
    return _isAvailable;
  }

  // ── Public API ─────────────────────────────────────────────────────────────
  Future<void> startAlwaysOn() async {
    if (!_isAvailable || _running) return;
    _running = true;
    logger.log('WakeWord: Hybrid mode started. Say "$wakeWord"');
    _listenForWakeWord();
  }

  Future<void> stop() async {
    _running = false;
    _cleanupTimers();
    await _speech.stop();
    if (await _recorder.isRecording()) await _recorder.stop();
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
    if ((status == 'notListening' || status == 'done') && _running) {
      _handleEngineStop();
    }
  }

  void _handleEngineStop() {
    if (!_running || _isStarting || _state != WakeState.idle) return;
    
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 800), () {
      if (_running && !_speech.isListening && !_isStarting && _state == WakeState.idle) {
        _listenForWakeWord();
      }
    });
  }

  Future<void> _listenForWakeWord() async {
    if (!_running || _isStarting || _speech.isListening) return;

    _isStarting = true;
    _setState(WakeState.idle);

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase().trim();
          if (words.contains(wakeWord)) {
            // We don't wait for finalResult here for faster response, 
            // but we use a debounce/state check inside _onWakeWordDetected.
            _onWakeWordDetected(words);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        cancelOnError: false,
      );
    } catch (e) {
      logger.log('WakeWord listen error: $e');
    } finally {
      _isStarting = false;
    }
  }

  void _onWakeWordDetected(String fullPhrase) async {
    if (_state != WakeState.idle) return; 
    
    _isStarting = true; 
    _setState(WakeState.awake);
    
    await _speech.cancel(); 
    _playActivationSound();
    
    // Check for inline command
    final afterWake = fullPhrase
        .split(wakeWord)
        .last
        .replaceAll(RegExp(r'[,.]'), '')
        .trim();

    if (afterWake.length > 3) {
      logger.log('WakeWord: Inline command: "$afterWake"');
      _isStarting = false;
      _dispatchCommand(afterWake);
    } else {
      final greeting = _greetings[_random.nextInt(_greetings.length)];
      await ttsService.speak(greeting);
      
      await Future.delayed(const Duration(milliseconds: 300));
      _isStarting = false;
      _startRecordingCommand();
    }
  }

  // ── High Quality Recording Phase ──────────────────────────────────────────

  Future<void> _startRecordingCommand() async {
    if (!_running || await _recorder.isRecording()) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final path = p.join(tempDir.path, 'command.m4a');
      
      // Delete old file if exists
      final oldFile = File(path);
      if (await oldFile.exists()) await oldFile.delete();

      logger.log('WakeWord: Recording command...');
      _setState(WakeState.awake);

      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

      // 1. Max duration safety
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(commandMaxDuration, _stopAndProcessRecording);

      // 2. Simple VAD (Silence detection)
      _silenceTimer?.cancel();
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((amp) {
        // -30dB to -40dB is usually a good threshold for silence in a quiet room
        if (amp.current < -40) {
          _silenceTimer ??= Timer(silenceDuration, _stopAndProcessRecording);
        } else {
          _silenceTimer?.cancel();
          _silenceTimer = null;
        }
      });

    } catch (e) {
      logger.log('Recording error: $e');
      _listenForWakeWord();
    }
  }

  Future<void> _stopAndProcessRecording() async {
    if (!await _recorder.isRecording()) return;

    _cleanupTimers();
    final path = await _recorder.stop();
    
    if (path == null) {
      _listenForWakeWord();
      return;
    }

    _setState(WakeState.processing);
    logger.log('WakeWord: Transcribing audio...');

    final text = await sttService.transcribe(path);
    
    if (text.trim().isNotEmpty) {
      _dispatchCommand(text);
    } else {
      logger.log('WakeWord: No speech detected in recording.');
      resumeListening();
    }
  }

  void _dispatchCommand(String command) {
    logger.log('WakeWord: Command → "$command"');
    _setState(WakeState.processing);
    onCommandDetected?.call(command);
  }

  void _cleanupTimers() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxDurationTimer?.cancel();
    _restartTimer?.cancel();
  }

  Future<void> _playActivationSound() async {
    try {
      HapticFeedback.mediumImpact();
      await _platform.invokeMethod('playActivationSound');
    } catch (_) {}
  }

  void resumeListening() {
    if (_running) {
      _isStarting = true;
      _speech.stop().then((_) {
        _isStarting = false;
        _setState(WakeState.idle);
        Future.delayed(const Duration(milliseconds: 500), _listenForWakeWord);
      });
    }
  }
}

final wakeWordService = WakeWordService();
