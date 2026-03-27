import 'package:speech_to_text/speech_to_text.dart';
import 'log_service.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  Future<bool> init() async {
    _isAvailable = await _speech.initialize(
      onStatus: (status) => logger.log('Speech status: $status'),
      onError: (error) => logger.log('Speech error: $error'),
    );
    logger.log("Speech initialization: ${_isAvailable ? 'Success' : 'Failed'}");
    return _isAvailable;
  }

  Future<void> startListening(Function(String) onResult) async {
    if (!_isAvailable) {
      logger.log("Speech: Not available");
      return;
    }
    logger.log("Speech: Starting listener");
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          logger.log("Speech final: ${result.recognizedWords}");
          onResult(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stopListening() async {
    logger.log("Speech: Stopping listener");
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
}
