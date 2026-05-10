import 'package:flutter/services.dart';
import 'log_service.dart';

/// Single responsibility: execute phone control actions via the platform channel.
///
/// Translates AI-returned action maps into native Android calls.
/// Returns true on success, false on failure.
class ActionExecutorService {
  static const _platform = MethodChannel('com.example.controller_phone/voice_control');

  /// Executes an action map returned by the AI service.
  /// Returns a human-readable result string for UI display.
  Future<String> execute(Map<String, dynamic> action) async {
    final type = action['action'] as String? ?? 'error';
    final customResponse = action['response'] as String?;
    logger.log('ActionExecutor: executing "$type"');

    try {
      String result = '';
      switch (type) {
        case 'back':
          await _platform.invokeMethod('performBack');
          result = 'Went back';
          break;

        case 'home':
          await _platform.invokeMethod('performHome');
          result = 'Went to home screen';
          break;

        case 'close':
          await _platform.invokeMethod('closeCurrentApp');
          result = 'Closing app via recents swipe';
          break;

        case 'recents':
          await _platform.invokeMethod('performRecents');
          result = 'Opened recents';
          break;

        case 'tap':
          final x = (action['x'] as num?)?.toDouble() ?? 0.0;
          final y = (action['y'] as num?)?.toDouble() ?? 0.0;
          logger.log('ActionExecutor: tap at ($x, $y)');
          await _platform.invokeMethod('performTap', {'x': x, 'y': y});
          result = 'Tapped ($x, $y)';
          break;

        case 'click':
          final label = action['label'] as String? ?? '';
          logger.log('ActionExecutor: click label "$label"');
          final clicked = await _platform.invokeMethod<bool>('clickByLabel', {'label': label});
          if (clicked == true) {
            result = 'Clicked "$label"';
          } else {
            logger.log('ActionExecutor: label "$label" not found on screen');
            result = 'I couldn\'t find the "$label" button on the screen.';
          }
          break;

        case 'open':
          final appName = action['text'] as String? ?? '';
          logger.log('ActionExecutor: launching app "$appName"');
          final launched = await _platform.invokeMethod<bool>('launchApp', {'name': appName});
          if (launched == true) {
            result = 'Opened $appName';
          } else {
            logger.log('ActionExecutor: app "$appName" not found');
            result = 'I couldn\'t find the $appName app on your phone.';
          }
          break;

        case 'say':
          result = action['text'] as String? ?? 'I have nothing to say.';
          break;

        case 'error':
          result = action['message'] as String? ?? 'I encountered an AI error.';
          break;

        default:
          logger.log('ActionExecutor: unknown action "$type"');
          result = 'Unknown action';
          break;
      }
      
      return customResponse ?? result;
    } on PlatformException catch (e) {
      logger.log('ActionExecutor: platform error — ${e.message}');
      return 'Platform error: ${e.message}';
    } catch (e) {
      logger.log('ActionExecutor: error — $e');
      return 'Error: $e';
    }
  }
}

final actionExecutorService = ActionExecutorService();
