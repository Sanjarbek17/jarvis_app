import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'action_executor_service.dart';
import 'log_service.dart';

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
      
      _channel!.ready.then((_) {
        isConnected.value = true;
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

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    isConnected.value = false;
  }
}

// Since the user is testing locally or on madaniyat, they can configure this URL.
// Replace this with the madaniyat IP/domain or local IP when deploying.
final remoteControlClient = RemoteControlClient(serverUrl: 'ws://95.46.161.3:10555/ws');
