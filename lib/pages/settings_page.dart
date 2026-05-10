import 'package:flutter/material.dart';
import '../services/qwen_ai_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _modelController = TextEditingController();
  bool _useHttps = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ipController.text = QwenAIService.macIp;
    _portController.text = QwenAIService.port.toString();
    _modelController.text = QwenAIService.model;
    _useHttps = QwenAIService.useHttps;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final model = _modelController.text.trim();

    if (ip.isEmpty || port == null || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid IP, Port and Model name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await QwenAIService.updateConfig(ip, port, _useHttps, model);
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
        title: const Text('Server Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
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
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.datetime, // for numbers and dots
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'e.g. 11434',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
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
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Use Secure Connection (HTTPS)', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Enable if your Ollama server uses SSL', style: TextStyle(color: Colors.white38, fontSize: 12)),
              value: _useHttps,
              onChanged: (bool value) {
                setState(() => _useHttps = value);
              },
              activeColor: Colors.blue,
              contentPadding: EdgeInsets.zero,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SAVE & RECONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
