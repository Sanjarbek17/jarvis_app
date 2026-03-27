import 'dart:convert';
import 'package:http/http.dart' as http;
import 'log_service.dart';

/// Single responsibility: communicate with the local Ollama AI server.
///
/// Translates (voice command + screen context) → action JSON.
/// All network, JSON parsing, and prompt construction lives here.
class QwenAIService {
  static bool _isInitialized = false;

  static const String _macIp = '192.168.43.104'; // Mac's LAN IP
  static String get macIp => _macIp;
  static const int _port = 11434;
  static const String _model = 'qwen2.5:0.5b';
  static const String _baseUrl = 'http://$_macIp:$_port';

  // ── Initialisation ──────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_isInitialized) return;
    logger.log('AI: Checking Ollama at $_baseUrl ...');
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final models = (jsonDecode(response.body)['models'] as List?)
                ?.map((m) => m['name'] as String)
                .toList() ??
            [];
        logger.log('AI: Ollama reachable. Models: $models');
        if (models.any((m) => m.contains('qwen2.5'))) {
          logger.log('AI: Qwen 2.5 found. Ready!');
          _isInitialized = true;
        } else {
          logger.log('AI: ⚠️  Run: ollama pull qwen2.5:0.5b');
        }
      }
    } catch (e) {
      logger.log('AI: Cannot reach Ollama — $e');
    }
  }

  // ── Inference ───────────────────────────────────────────────────────────────

  /// Translates a voice [command] into an action map.
  ///
  /// [screenContent] is the current visible text/elements on screen.
  /// Passing it allows the AI to make context-aware decisions
  /// (e.g. clicking a real button by label instead of guessing coordinates).
  static Future<Map<String, dynamic>> getAction(
    String command, {
    String screenContent = '',
  }) async {
    if (!_isInitialized) await initialize();

    logger.log("AI: Processing: '$command'");
    if (screenContent.isNotEmpty) {
      logger.log('AI: Screen context (${screenContent.length} chars)');
    }

    final systemPrompt = _buildSystemPrompt(screenContent);

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': command},
      ],
      'stream': false,
      'options': {
        'temperature': 0.1,
        'num_predict': 48,
      },
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['message']?['content'] as String? ?? '';
        logger.log('AI: Raw response: $content');
        return _parseAction(content);
      }
      logger.log('AI: HTTP ${response.statusCode}');
    } catch (e) {
      logger.log('AI Error: $e');
    }
    return {'action': 'error', 'message': 'Ollama request failed'};
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static String _buildSystemPrompt(String screenContent) {
    final screenSection = screenContent.isNotEmpty
        ? '\n\nCurrent screen:\n$screenContent'
        : '';

    return '''You control an Android phone. Reply ONLY with one JSON object.

Available actions:
{"action":"back"}
{"action":"home"}
{"action":"close"}
{"action":"recents"}
{"action":"open","text":"<app name>"}
{"action":"click","label":"<exact button text from screen>"}
{"action":"tap","x":<number>,"y":<number>}

Rules:
- Use "close" when user says close/exit/quit the app.
- Prefer "click" with a label from the screen over blind "tap".
- Use "open" to launch apps by name.
- Only output JSON, no explanation.$screenSection''';
  }

  static Map<String, dynamic> _parseAction(String content) {
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
    if (match != null) {
      try {
        final result = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        logger.log("AI: Action → ${result['action']}");
        return result;
      } catch (_) {}
    }
    logger.log('AI: Could not parse JSON from: $content');
    return {'action': 'error', 'message': 'Could not parse response'};
  }
}
