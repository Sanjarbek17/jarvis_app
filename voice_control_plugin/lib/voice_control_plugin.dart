
import 'voice_control_plugin_platform_interface.dart';

class VoiceControlPlugin {
  Future<String?> getPlatformVersion() {
    return VoiceControlPluginPlatform.instance.getPlatformVersion();
  }
}
