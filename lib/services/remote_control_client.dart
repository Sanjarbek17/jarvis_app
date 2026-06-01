import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'action_executor_service.dart';
import 'log_service.dart';
import '../utils/platform_util.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:package_info_plus/package_info_plus.dart';

class RemoteControlClient {
  static String appVersion = '1.0.0';
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  final String serverUrl;
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  bool isBackground = false;

  static Future<void> initVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      logger.log('Failed to get package version: $e');
    }
  }

  RemoteControlClient({required this.serverUrl});

  void initForegroundChannel() {
    if (kIsWeb) return;
    isBackground = false;
    
    // Listen to updates from the background service
    FlutterBackgroundService().on('update_status').listen((event) {
      if (event != null && event['connected'] != null) {
        isConnected.value = event['connected'] as bool;
      }
    });
    
    // Periodically check if service is running and query status
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final running = await FlutterBackgroundService().isRunning();
      if (!running) {
        if (isConnected.value) {
          isConnected.value = false;
        }
      } else {
        FlutterBackgroundService().invoke('query_status');
      }
    });
  }

  void connect() {
    if (!isBackground && !kIsWeb) {
      logger.log('Client connect called from UI: starting background service');
      FlutterBackgroundService().startService();
      return;
    }
    try {
      logger.log('Connecting to remote control server: $serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      
      _channel!.ready.then((_) async {
        isConnected.value = true;
        if (isBackground) {
          FlutterBackgroundService().invoke('update_status', {'connected': true});
        }
        logger.logs.addListener(_onLogAdded);
        try {
          final size = await PlatformUtil.getScreenSize();
          if (size != null) {
            final width = size['width'];
            final height = size['height'];
            final accessibilityActive = await PlatformUtil.isAccessibilityServiceEnabled();
            final msg = jsonEncode({
              'type': 'device_size',
              'width': width,
              'height': height,
              'version': appVersion,
              'accessibility_active': accessibilityActive,
            });
            _channel!.sink.add(msg);
            logger.log('Sent device size, version, and accessibility status to server: ${width}x${height}, version: $appVersion, active: $accessibilityActive');
          }
        } catch (e) {
          logger.log('Failed to send device info: $e');
        }
      });

      _channel!.stream.listen(
        (message) async {
          logger.log('Received command from server: $message');
          try {
            final Map<String, dynamic> action = jsonDecode(message);
            await actionExecutorService.execute(action);
          } catch (e) {
            logger.log('Error parsing or executing command: $e');
          }
        },
        onDone: () {
          logger.log('Remote control server disconnected.');
          isConnected.value = false;
          if (isBackground) {
            FlutterBackgroundService().invoke('update_status', {'connected': false});
          }
          _scheduleReconnect();
        },
        onError: (error) {
          logger.log('Remote control server error: $error');
          isConnected.value = false;
          if (isBackground) {
            FlutterBackgroundService().invoke('update_status', {'connected': false});
          }
          _scheduleReconnect();
        },
      );
    } catch (e) {
      logger.log('Failed to connect to remote control server: $e');
      _scheduleReconnect();
    }
  }

  void _onLogAdded() {
    if (_channel != null && isConnected.value) {
      final latestLog = logger.logs.value.last;
      // Filter out transmission logs to prevent recursive loops
      if (!latestLog.contains('Screenshot sent') && 
          !latestLog.contains('Sending log') && 
          !latestLog.contains('device_size')) {
        _channel!.sink.add(jsonEncode({'type': 'log', 'message': latestLog}));
      }
    }
  }

  void _scheduleReconnect() {
    logger.logs.removeListener(_onLogAdded);
    _channel?.sink.close();
    _channel = null;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      logger.log('Attempting to reconnect...');
      connect();
    });
  }

  void sendScreenshot(String base64Png) {
    if (_channel == null || !isConnected.value) {
      logger.log('sendScreenshot: not connected, cannot send screenshot');
      return;
    }
    final msg = jsonEncode({'type': 'screenshot', 'data': base64Png});
    _channel!.sink.add(msg);
    logger.log('Screenshot sent to server (${base64Png.length} chars base64)');
  }

  void disconnect() {
    if (!isBackground && !kIsWeb) {
      logger.log('Client disconnect called from UI: stopping background service');
      FlutterBackgroundService().invoke('stopService');
      return;
    }
    logger.logs.removeListener(_onLogAdded);
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    isConnected.value = false;
    if (isBackground) {
      FlutterBackgroundService().invoke('update_status', {'connected': false});
    }
  }
}

// Since the user is testing locally or on madaniyat, they can configure this URL.
// Replace this with the madaniyat IP/domain or local IP when deploying.
final remoteControlClient = RemoteControlClient(serverUrl: 'ws://95.46.161.3:10555/ws');
