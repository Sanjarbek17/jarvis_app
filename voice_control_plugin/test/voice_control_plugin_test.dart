import 'package:flutter_test/flutter_test.dart';
import 'package:voice_control_plugin/voice_control_plugin.dart';
import 'package:voice_control_plugin/voice_control_plugin_platform_interface.dart';
import 'package:voice_control_plugin/voice_control_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVoiceControlPluginPlatform
    with MockPlatformInterfaceMixin
    implements VoiceControlPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VoiceControlPluginPlatform initialPlatform = VoiceControlPluginPlatform.instance;

  test('$MethodChannelVoiceControlPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVoiceControlPlugin>());
  });

  test('getPlatformVersion', () async {
    VoiceControlPlugin voiceControlPlugin = VoiceControlPlugin();
    MockVoiceControlPluginPlatform fakePlatform = MockVoiceControlPluginPlatform();
    VoiceControlPluginPlatform.instance = fakePlatform;

    expect(await voiceControlPlugin.getPlatformVersion(), '42');
  });
}
