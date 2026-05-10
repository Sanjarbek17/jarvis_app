import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'log_service.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  Completer<void>? _speechCompleter;

  Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    
    _tts.setErrorHandler((msg) {
      logger.log("TTS Error: $msg");
      _speechCompleter?.complete();
      _speechCompleter = null;
    });

    _tts.setCompletionHandler(() {
      _speechCompleter?.complete();
      _speechCompleter = null;
    });

    _isInitialized = true;
    logger.log("TTS Service Initialized");
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    logger.log("Jarvis speaking: $text");
    
    // Stop any current speech and complete its future
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      await _tts.stop();
      _speechCompleter?.complete();
    }

    _speechCompleter = Completer<void>();
    await _tts.speak(text);
    return _speechCompleter!.future;
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}

final ttsService = TtsService();
