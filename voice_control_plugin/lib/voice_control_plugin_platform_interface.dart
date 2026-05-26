import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'voice_control_plugin_method_channel.dart';

abstract class VoiceControlPluginPlatform extends PlatformInterface {
  /// Constructs a VoiceControlPluginPlatform.
  VoiceControlPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static VoiceControlPluginPlatform _instance = MethodChannelVoiceControlPlugin();

  /// The default instance of [VoiceControlPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelVoiceControlPlugin].
  static VoiceControlPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VoiceControlPluginPlatform] when
  /// they register themselves.
  static set instance(VoiceControlPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
