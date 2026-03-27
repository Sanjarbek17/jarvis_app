import 'package:flutter/foundation.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final ValueNotifier<List<String>> logs = ValueNotifier<List<String>>([]);

  void log(String message) {
    debugPrint(message);
    final timestamp = DateTime.now().toString().split('.').first.split(' ').last;
    final logEntry = "$timestamp: $message";
    
    // Update the list and notify listeners
    final currentLogs = List<String>.from(logs.value);
    currentLogs.add(logEntry);
    logs.value = currentLogs;
  }

  void clear() {
    logs.value = [];
  }
}

final logger = LogService();
