import '../services/wake_word_service.dart';
import '../services/qwen_ai_service.dart';
import '../services/screen_reader_service.dart';
import '../services/action_executor_service.dart';

class CommandOrchestrator {
  static Future<void> processCommand({
    required String words,
    required Function(String status) onStatusUpdate,
    required Function() onFinish,
  }) async {
    // 1. Read screen
    onStatusUpdate('Reading screen...');
    final screenContent = await screenReaderService.getScreenContent();

    // 2. AI Inference
    onStatusUpdate('AI Thinking...');
    final action = await QwenAIService.getAction(words, screenContent: screenContent);

    // 3. Execute
    onStatusUpdate("Executing: ${action['action']}");
    final resultMsg = await actionExecutorService.execute(action);
    onStatusUpdate(resultMsg);

    // 4. Cleanup
    await Future.delayed(const Duration(milliseconds: 500));
    wakeWordService.resumeListening();
    onFinish();
  }
}
