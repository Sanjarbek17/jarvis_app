import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/qwen_ai_service.dart';
import '../services/stt_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _modelController = TextEditingController();
  final _sttUrlController = TextEditingController();
  final _sttModelController = TextEditingController();
  bool _useHttps = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ipController.text = QwenAIService.macIp;
    _portController.text = QwenAIService.port.toString();
    _modelController.text = QwenAIService.model;
    _useHttps = QwenAIService.useHttps;
    _loadSttConfig();
  }

  Future<void> _loadSttConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sttUrlController.text =
          prefs.getString('stt_server_url') ??
          'http://95.46.161.3:8112/transcribe';
      _sttModelController.text = prefs.getString('stt_model') ?? 'whisper-1';
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _modelController.dispose();
    _sttUrlController.dispose();
    _sttModelController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final model = _modelController.text.trim();
    final sttUrl = _sttUrlController.text.trim();
    final sttModel = _sttModelController.text.trim();

    if (ip.isEmpty || port == null || model.isEmpty || sttUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await QwenAIService.updateConfig(ip, port, _useHttps, model);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stt_server_url', sttUrl);
    await prefs.setString('stt_model', sttModel);
    await SttService.initialize();

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OLLAMA CONFIGURATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Mac LAN IP',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'e.g. 192.168.1.5',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'e.g. 11434',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model Name',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'e.g. qwen2.5:0.5b',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text(
                'Use Secure Connection (HTTPS)',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: const Text(
                'Enable if your Ollama server uses SSL',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              value: _useHttps,
              onChanged: (bool value) {
                setState(() => _useHttps = value);
              },
              activeThumbColor: Colors.blue,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 40),
            const Text(
              'SELF-HOSTED STT (WHISPER)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _sttUrlController,
              decoration: const InputDecoration(
                labelText: 'Whisper Server URL',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'http://.../transcribe',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orangeAccent),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _sttModelController,
              decoration: const InputDecoration(
                labelText: 'Whisper Model',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'whisper-1',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orangeAccent),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SAVE SETTINGS',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
