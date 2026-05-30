import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'action_executor_service.dart';
import 'log_service.dart';
import '../utils/platform_util.dart';

class RemoteControlClient {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  final String serverUrl;
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  RemoteControlClient({required this.serverUrl});

  void connect() {
    try {
      logger.log('Connecting to remote control server: $serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      
      _channel!.ready.then((_) async {
        isConnected.value = true;
        try {
          final size = await PlatformUtil.getScreenSize();
          if (size != null) {
            final width = size['width'];
            final height = size['height'];
            final msg = jsonEncode({
              'type': 'device_size',
              'width': width,
              'height': height,
            });
            _channel!.sink.add(msg);
            logger.log('Sent device size to server: ${width}x${height}');
          }
        } catch (e) {
          logger.log('Failed to send device size: $e');
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
          _scheduleReconnect();
        },
        onError: (error) {
          logger.log('Remote control server error: $error');
          isConnected.value = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      logger.log('Failed to connect to remote control server: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
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
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    isConnected.value = false;
  }
}

// Since the user is testing locally or on madaniyat, they can configure this URL.
// Replace this with the madaniyat IP/domain or local IP when deploying.
final remoteControlClient = RemoteControlClient(serverUrl: 'ws://95.46.161.3:10555/ws');
