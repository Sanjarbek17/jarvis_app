import '../services/wake_word_service.dart';
import '../services/qwen_ai_service.dart';
import '../services/screen_reader_service.dart';
import '../services/action_executor_service.dart';
import '../services/tts_service.dart';

class CommandOrchestrator {
  static Future<void> processCommand({
    required String words,
    required Function(String status) onStatusUpdate,
    required Function() onFinish,
  }) async {
    try {
      // 1. Read screen
      onStatusUpdate('Reading screen...');
      final screenContent = await screenReaderService.getScreenContent();

      // 2. AI Inference
      onStatusUpdate('AI Thinking...');
      final action = await QwenAIService.getAction(words, screenContent: screenContent);

      if (action['action'] == 'error') {
        final errorMsg = action['message'] ?? 'I encountered an AI error.';
        onStatusUpdate('Error: $errorMsg');
        await ttsService.speak(errorMsg);
      } else {
        // 3. Execute
        onStatusUpdate("Executing: ${action['action']}");
        final resultMsg = await actionExecutorService.execute(action);
        onStatusUpdate(resultMsg);
        
        // Speak the result to the user
        await ttsService.speak(resultMsg);
      }
    } catch (e) {
      final errorMsg = "I'm sorry, something went wrong while processing your request.";
      onStatusUpdate('Fatal Error: $e');
      await ttsService.speak(errorMsg);
    } finally {
      // 4. Cleanup
      await Future.delayed(const Duration(milliseconds: 500));
      wakeWordService.resumeListening();
      onFinish();
    }
  }
}
