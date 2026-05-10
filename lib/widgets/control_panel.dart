import 'package:flutter/material.dart';
import '../services/action_executor_service.dart';
import '../services/qwen_ai_service.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text(
            'DIRECT CONTROLS',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SmallControl(Icons.arrow_back, 'BACK', () => actionExecutorService.execute({'action': 'back'})),
              _SmallControl(Icons.home, 'HOME', () => actionExecutorService.execute({'action': 'home'})),
              _SmallControl(Icons.layers, 'RECENTS', () => actionExecutorService.execute({'action': 'recents'})),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          const Text(
            'AI SERVER',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.computer, color: Colors.blue),
            title: const Text('Ollama on Mac (LAN)', style: TextStyle(fontSize: 14, color: Colors.white)),
            subtitle: Text(
              'qwen2.5:0.5b @ ${QwenAIService.macIp}:${QwenAIService.port}',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade300),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () async {
                await QwenAIService.initialize();
              },
              tooltip: 'Re-check connection',
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallControl(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}
