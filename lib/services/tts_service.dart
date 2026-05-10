import 'package:flutter_tts/flutter_tts.dart';
import 'log_service.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    
    _tts.setErrorHandler((msg) {
      logger.log("TTS Error: $msg");
    });

    _isInitialized = true;
    logger.log("TTS Service Initialized");
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    logger.log("Jarvis speaking: $text");
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}

final ttsService = TtsService();
