import 'package:flutter/services.dart';
import '../services/log_service.dart';

class PlatformUtil {
  static const _platform = MethodChannel('com.example.controller_phone/voice_control');

  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final enabled = await _platform.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return enabled ?? false;
    } catch (e) {
      logger.log("Error checking accessibility: $e");
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    logger.log('Opening accessibility settings...');
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      logger.log('Failed to open settings: $e');
    }
  }

  static Future<Map<String, int>?> getScreenSize() async {
    try {
      final size = await _platform.invokeMapMethod<String, int>('getScreenSize');
      return size;
    } catch (e) {
      logger.log("Error getting screen size: $e");
      return null;
    }
  }

  static Future<bool> requestScreenCapturePermission() async {
    try {
      final granted = await _platform.invokeMethod<bool>('requestScreenCapturePermission');
      return granted ?? false;
    } catch (e) {
      logger.log("Error requesting screen capture: $e");
      return false;
    }
  }
}
