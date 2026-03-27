import 'package:flutter/services.dart';

/// Single responsibility: read screen content from the Accessibility Service.
///
/// Returns a compact text snapshot of what is currently visible on screen,
/// including window title, visible text, buttons, and input fields.
class ScreenReaderService {
  static const _platform = MethodChannel('com.example.controller_phone/voice_control');

  /// Fetches the current screen content.
  /// Returns an empty string if the accessibility service is not connected.
  Future<String> getScreenContent() async {
    try {
      final content = await _platform
          .invokeMethod<String>('getScreenContent')
          .timeout(const Duration(seconds: 3));
      return content ?? '';
    } catch (e) {
      return '';
    }
  }
}

final screenReaderService = ScreenReaderService();
