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
    logger.log('ActionExecutor: executing "$type"');

    try {
      switch (type) {
        case 'back':
          await _platform.invokeMethod('performBack');
          return 'Went back';

        case 'home':
          await _platform.invokeMethod('performHome');
          return 'Went to home screen';

        case 'close':
          // Opens recents and swipes the top app card up to dismiss it.
          await _platform.invokeMethod('closeCurrentApp');
          return 'Closing app via recents swipe';

        case 'recents':
          await _platform.invokeMethod('performRecents');
          return 'Opened recents';

        case 'tap':
          final x = (action['x'] as num?)?.toDouble() ?? 0.0;
          final y = (action['y'] as num?)?.toDouble() ?? 0.0;
          logger.log('ActionExecutor: tap at ($x, $y)');
          await _platform.invokeMethod('performTap', {'x': x, 'y': y});
          return 'Tapped ($x, $y)';

        case 'click':
          // Context-aware click: uses accessibility to find element by label
          final label = action['label'] as String? ?? '';
          logger.log('ActionExecutor: click label "$label"');
          final clicked = await _platform.invokeMethod<bool>('clickByLabel', {'label': label});
          if (clicked == true) return 'Clicked "$label"';
          logger.log('ActionExecutor: label "$label" not found on screen');
          return 'Button "$label" not found';

        case 'open':
          final appName = action['text'] as String? ?? '';
          logger.log('ActionExecutor: launching app "$appName"');
          final launched = await _platform.invokeMethod<bool>('launchApp', {'name': appName});
          if (launched == true) return 'Opened $appName';
          logger.log('ActionExecutor: app "$appName" not found');
          return 'App "$appName" not found';

        case 'error':
          return action['message'] as String? ?? 'AI error';

        default:
          logger.log('ActionExecutor: unknown action "$type"');
          return 'Unknown action';
      }
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
