import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart';

class SttService {
  static final SttService _instance = SttService._internal();
  factory SttService() => _instance;
  SttService._internal();

  static String _serverUrl = 'http://95.46.161.3:8112/v1/audio/transcriptions';
  static String _model = 'base';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString('stt_server_url') ?? 'http://95.46.161.3:8112/v1/audio/transcriptions';
    _model = prefs.getString('stt_model') ?? 'base';
    logger.log('STT: Local Whisper initialized at $_serverUrl');
  }

  static Future<void> updateConfig(String url, String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stt_server_url', url);
    await prefs.setString('stt_model', model);
    _serverUrl = url;
    _model = model;
  }

  /// Transcribes the given audio file using a custom Whisper server.
  Future<String> transcribe(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      logger.log('STT Error: Audio file does not exist at $filePath');
      return '';
    }

    logger.log('STT: Sending audio to custom server at $_serverUrl');

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_serverUrl),
      );

      // standard OpenAI-compatible fields if your server supports them
      request.fields['model'] = _model;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Expecting {"text": "..."} - standard Whisper output
        final text = data['text'] as String? ?? '';
        logger.log('STT Result: "$text"');
        return text;
      } else {
        logger.log('STT Error: ${response.statusCode} - ${response.body}');
        return '';
      }
    } catch (e) {
      logger.log('STT Exception: $e');
      return '';
    }
  }
}

final sttService = SttService();
