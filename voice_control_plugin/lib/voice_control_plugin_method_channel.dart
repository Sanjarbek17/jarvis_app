import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'voice_control_plugin_platform_interface.dart';

/// An implementation of [VoiceControlPluginPlatform] that uses method channels.
class MethodChannelVoiceControlPlugin extends VoiceControlPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('voice_control_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
