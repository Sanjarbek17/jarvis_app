import 'package:flutter/material.dart';
import '../pages/settings_page.dart';
import 'status_indicator.dart';

class AppHeader extends StatelessWidget {
  final bool isAccessibilityEnabled;
  final VoidCallback onRequestAccessibility;

  const AppHeader({
    super.key,
    required this.isAccessibilityEnabled,
    required this.onRequestAccessibility,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHONE CONTROLLER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.blue.shade400,
                ),
              ),
              const Text(
                'Voice Assistant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              StatusIndicator(
                isEnabled: isAccessibilityEnabled,
                onRequest: onRequestAccessibility,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
