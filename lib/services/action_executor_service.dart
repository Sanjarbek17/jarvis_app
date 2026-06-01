import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/platform_util.dart';
import 'log_service.dart';
import 'remote_control_client.dart';

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
          final res = await _platform.invokeMethod('performHome');
          result = 'Went to home screen: $res';
          break;

        case 'screenshot':
          logger.log('ActionExecutor: taking screenshot');
          final b64 = await _platform.invokeMethod<String>('takeScreenshot');
          logger.log('takeScreenshot result raw: ${b64 != null ? (b64.length > 50 ? b64.substring(0, 50) : b64) : 'null'}');
          if (b64 != null && b64.isNotEmpty && !b64.startsWith('ERROR_')) {
            remoteControlClient.sendScreenshot(b64);
            result = 'Screenshot captured and sent';
          } else {
            result = 'Screenshot failed: $b64';
          }
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

        case 'swipe':
          final x1 = (action['x'] as num?)?.toDouble() ?? 0.0;
          final y1 = (action['y'] as num?)?.toDouble() ?? 0.0;
          final x2 = (action['x2'] as num?)?.toDouble() ?? 0.0;
          final y2 = (action['y2'] as num?)?.toDouble() ?? 0.0;
          final duration = (action['duration'] as num?)?.toInt() ?? 300;
          logger.log('ActionExecutor: swipe from ($x1, $y1) to ($x2, $y2)');
          await _platform.invokeMethod('performSwipe', {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
            'duration': duration,
          });
          result = 'Swiped from ($x1, $y1) to ($x2, $y2)';
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

        case 'write':
          final text = action['text'] as String? ?? '';
          logger.log('ActionExecutor: write/type text "$text"');
          final success = await _platform.invokeMethod<bool>('writeText', {'text': text});
          if (success == true) {
            result = 'Wrote "$text"';
          } else {
            result = 'Failed to write "$text" (no active focused input?)';
          }
          break;

        case 'wakeup':
          logger.log('ActionExecutor: waking up screen');
          final success = await _platform.invokeMethod<bool>('wakeUp');
          result = success == true ? 'Screen woke up' : 'Failed to wake up screen';
          break;

        case 'say':
          result = action['text'] as String? ?? 'I have nothing to say.';
          break;

        case 'error':
          result = action['message'] as String? ?? 'I encountered an AI error.';
          break;

        case 'update':
          final url = action['url'] as String? ?? '';
          if (url.isEmpty) {
            result = 'Update error: URL is empty';
            break;
          }
          logger.log('ActionExecutor: starting update from $url');
          try {
            final tempDir = await getTemporaryDirectory();
            final apkPath = '${tempDir.path}/app-update.apk';
            
            // Download the file
            final dio = Dio();
            logger.log('Downloading APK to $apkPath...');
            await dio.download(url, apkPath);
            logger.log('Download complete. Triggering install...');
            
            final success = await PlatformUtil.installApk(apkPath);
            result = success ? 'App installation started' : 'Failed to start app installation';
          } catch (e) {
            logger.log('Update error: $e');
            result = 'Update failed: $e';
          }
          break;

        default:
          logger.log('ActionExecutor: unknown action "$type"');
          result = 'Unknown action';
          break;
      }
      
      logger.log('ActionExecutor: Result = ${customResponse ?? result}');
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
