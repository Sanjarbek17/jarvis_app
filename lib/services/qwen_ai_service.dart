import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart';

/// Single responsibility: communicate with the local Ollama AI server.
///
/// Translates (voice command + screen context) → action JSON.
/// All network, JSON parsing, and prompt construction lives here.
class QwenAIService {
  static bool _isInitialized = false;

  static String _macIp = '192.168.43.104'; // Default Mac's LAN IP
  static int _port = 11434;
  static bool _useHttps = false;
  static String _model = 'qwen3:0.6b';

  static String get macIp => _macIp;
  static int get port => _port;
  static bool get useHttps => _useHttps;
  static String get model => _model;
  static String get _baseUrl =>
      '${_useHttps ? 'https' : 'http'}://$_macIp:$_port';

  // ── Initialisation ──────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    // Load config from preferences
    final prefs = await SharedPreferences.getInstance();
    _macIp = prefs.getString('ollama_ip') ?? '95.46.161.3';
    _port = prefs.getInt('ollama_port') ?? 8111;
    _useHttps = prefs.getBool('ollama_https') ?? false;
    _model = prefs.getString('ollama_model') ?? 'qwen2.5:0.5b';

    logger.log('AI: Checking Ollama at $_baseUrl ...');
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final models =
            (jsonDecode(response.body)['models'] as List?)
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

  static Future<void> updateConfig(
    String ip,
    int port,
    bool useHttps,
    String model,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ollama_ip', ip);
    await prefs.setInt('ollama_port', port);
    await prefs.setBool('ollama_https', useHttps);
    await prefs.setString('ollama_model', model);
    _macIp = ip;
    _port = port;
    _useHttps = useHttps;
    _model = model;
    _isInitialized = false; // Force re-initialization with new config
    await initialize();
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

    // 1. Hardcoded special cases (fast path)
    final lowerCommand = command.toLowerCase();
    final lowerScreen = screenContent.toLowerCase();
    if ((lowerCommand.contains('yes') || lowerCommand.contains('allow')) &&
        (lowerScreen.contains('usb') || lowerScreen.contains('transfer'))) {
      logger.log('AI: USB transfer context detected. Tapping above back button.');
      return {
        'action': 'tap',
        'x': 900.0,
        'y': 2200.0,
        'response': 'Confirmed USB file transfer for you.'
      };
    }

    try {
      // 2. Step 1: Thinking phase
      logger.log("AI: --- Phase 1: Thinking ---");
      final thought = await _getThought(command, screenContent);
      logger.log("AI: Thought → $thought");

      // 3. Step 2: Action phase (Convert thought to JSON)
      logger.log("AI: --- Phase 2: Action ---");
      final actionContent = await _getActionJson(command, screenContent, thought);
      logger.log("AI: Raw JSON response → $actionContent");

      return _parseAction(actionContent);
    } catch (e) {
      logger.log('AI Error: $e');
      return {'action': 'error', 'message': 'I encountered a problem thinking about that.'};
    }
  }

  // ── Step 1: Thinking ───────────────────────────────────────────────────────

  static Future<String> _getThought(String command, String screenContent) async {
    final systemPrompt = '''You are Jarvis, an AI phone assistant. 
Analyze the user's request and the current screen. 
Think step-by-step about what phone action is needed (back, home, close, recents, open, click, or tap).
Explain your reasoning clearly.

Current screen content:
$screenContent''';

    return _ollamaChat(systemPrompt, command, temperature: 0.7);
  }

  // ── Step 2: Action Generation ──────────────────────────────────────────────

  static Future<String> _getActionJson(String command, String screenContent, String thought) async {
    final systemPrompt = '''Based on your previous reasoning, output the final command in JSON format.
Reply ONLY with the JSON object. No explanation.

Required structure:
{
  "action": "one of: back, home, close, recents, open, click, tap, say",
  "response": "What you say back to the user",
  "label": "exact text if clicking",
  "text": "app name if opening",
  "x": number, "y": number (if tapping)
}

Reasoning to follow:
$thought''';

    final userPrompt = "Generate the JSON for: '$command'";
    return _ollamaChat(systemPrompt, userPrompt, temperature: 0.1);
  }

  // ── Ollama HTTP Helper ─────────────────────────────────────────────────────

  static Future<String> _ollamaChat(String system, String user, {double temperature = 0.1}) async {
    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'stream': false,
      'options': {'temperature': temperature, 'num_predict': 256},
    });

    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['message']?['content'] as String? ?? '';
    }
    throw Exception('Ollama HTTP ${response.statusCode}');
  }

  static Map<String, dynamic> _parseAction(String content) {
    // 1. Try to find JSON block in markdown code fences
    final codeBlockMatch = RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true).firstMatch(content);
    String jsonString = codeBlockMatch?.group(1) ?? '';

    // 2. Fallback: Find anything between the first { and last }
    if (jsonString.isEmpty) {
      final match = RegExp(r'(\{.*\})', dotAll: true).firstMatch(content);
      jsonString = match?.group(1) ?? content;
    }

    try {
      final result = jsonDecode(jsonString.trim()) as Map<String, dynamic>;
      logger.log("AI: Action → ${result['action']}");
      return result;
    } catch (e) {
      logger.log('AI: JSON parse error: $e. Content: $content');
      // If parsing fails, try one more aggressive cleanup: find the first { and last } manually
      try {
        final start = jsonString.indexOf('{');
        final end = jsonString.lastIndexOf('}');
        if (start != -1 && end != -1) {
          final cleaned = jsonString.substring(start, end + 1);
          return jsonDecode(cleaned) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    
    return {'action': 'error', 'message': 'I couldn\'t understand the AI\'s response format.'};
  }
}
